package com.downplayer.downplayer

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.webkit.CookieManager
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Puente entre Flutter y el motor de descarga (yt-dlp, a través de youtubedl-android).
 * Todo el trabajo pesado corre en hilos aparte; las respuestas vuelven al hilo principal.
 * El código Dart que lo usa está en lib/services/engine.dart.
 */
class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private val workers = Executors.newCachedThreadPool()
    private var channel: MethodChannel? = null
    private var pendingSharedText: String? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "downplayer/engine")
            .apply { setMethodCallHandler(::onMethodCall) }
        rememberSharedText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        rememberSharedText(intent)
        pendingSharedText?.let { channel?.invokeMethod("sharedText", it) }
        pendingSharedText = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> background(result) { Engine.ensureInit(applicationContext); Engine.version(applicationContext) }
            "version" -> background(result) { Engine.version(applicationContext) }
            "update" -> background(result) { Engine.update(applicationContext) }
            "getInfo" -> background(result) {
                Engine.getInfo(
                    applicationContext,
                    call.argument<String>("url")!!,
                    call.argument<Boolean>("playlist") ?: false,
                    call.argument<String>("cookies"),
                )
            }
            "download" -> {
                val id = call.argument<String>("id")!!
                background(result) {
                    Engine.download(
                        applicationContext,
                        id,
                        call.argument<String>("url")!!,
                        call.argument<List<String>>("args") ?: emptyList(),
                        call.argument<String>("cookies"),
                    ) { progress, eta, line ->
                        main.post {
                            channel?.invokeMethod(
                                "progress",
                                mapOf("id" to id, "progress" to progress.toDouble(), "eta" to eta, "line" to line),
                            )
                        }
                    }
                }
            }
            "cancel" -> result.success(YoutubeDL.getInstance().destroyProcessById(call.argument<String>("id")!!))
            "saveToGallery" -> background(result) {
                saveToGallery(call.argument<String>("path")!!, call.argument<Boolean>("audio") ?: false)
            }
            "deleteMedia" -> background(result) { deleteMedia(call.argument<String>("uri")!!) }
            "mediaExists" -> background(result) { mediaExists(call.argument<String>("uri")!!) }
            "share" -> result.success(
                share(call.argument<String>("uri")!!, call.argument<String>("mime")!!, call.argument<String>("title")),
            )
            "openWith" -> result.success(
                openWith(call.argument<String>("uri")!!, call.argument<String>("mime")!!, call.argument<String>("title")),
            )
            "openUrl" -> result.success(tryStart(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!))))
            "saveCookies" -> result.success(
                saveCookies(call.argument<String>("domain")!!, call.argument<String>("required")!!),
            )
            "clearCookies" -> {
                clearCookies(call.argument<String>("domain")!!)
                result.success(null)
            }
            "takeSharedText" -> {
                result.success(pendingSharedText)
                pendingSharedText = null
            }
            "needsStoragePermission" -> result.success(needsStoragePermission())
            "requestStoragePermission" -> requestStoragePermission(result)
            else -> result.notImplemented()
        }
    }

    /** Corre [work] en un hilo aparte y entrega el resultado (o el error) a Flutter. */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        workers.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: YoutubeDL.CanceledException) {
                main.post { result.error("canceled", "Descarga cancelada", null) }
            } catch (e: Throwable) {
                main.post { result.error("failed", e.message ?: e.toString(), null) }
            }
        }
    }

    // ---------- Enlaces compartidos desde otras apps ----------

    private fun rememberSharedText(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND) {
            intent.getStringExtra(Intent.EXTRA_TEXT)?.let { pendingSharedText = it }
        }
    }

    // ---------- Galería ----------

    /** Mueve el archivo descargado a Películas/DownPlayer o Música/DownPlayer. Devuelve un content:// */
    private fun saveToGallery(path: String, audio: Boolean): String {
        val source = File(path)
        val mime = mimeFor(source.extension, audio)
        val folder = if (audio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (audio) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$folder/DownPlayer")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(collection, values)
                ?: throw IOException("No se pudo crear el archivo en la galería")
            try {
                contentResolver.openOutputStream(uri)!!.use { out ->
                    source.inputStream().use { it.copyTo(out) }
                }
            } catch (e: Exception) {
                contentResolver.delete(uri, null, null)
                throw e
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            source.parentFile?.deleteRecursively()
            return uri.toString()
        }

        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(folder), "DownPlayer")
        dir.mkdirs()
        var target = File(dir, source.name)
        var n = 1
        while (target.exists()) {
            target = File(dir, "${source.nameWithoutExtension} ($n).${source.extension}")
            n++
        }
        source.copyTo(target)
        source.parentFile?.deleteRecursively()

        // Registra el archivo en la galería y espera su content://
        var scanned: Uri? = null
        val latch = CountDownLatch(1)
        MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), arrayOf(mime)) { _, uri ->
            scanned = uri
            latch.countDown()
        }
        latch.await(10, TimeUnit.SECONDS)
        return (scanned ?: Uri.fromFile(target)).toString()
    }

    private fun deleteMedia(uri: String): Boolean =
        try {
            val parsed = Uri.parse(uri)
            if (parsed.scheme == "file") File(parsed.path!!).delete()
            else contentResolver.delete(parsed, null, null) > 0
        } catch (e: Exception) {
            // Por ejemplo, si la app se reinstaló y ya no es dueña del archivo.
            false
        }

    private fun mediaExists(uri: String): Boolean =
        try {
            val parsed = Uri.parse(uri)
            if (parsed.scheme == "file") File(parsed.path!!).exists()
            else contentResolver.openFileDescriptor(parsed, "r")?.use { true } ?: false
        } catch (e: Exception) {
            false
        }

    private fun mimeFor(extension: String, audio: Boolean): String =
        when (extension.lowercase()) {
            "mp4" -> if (audio) "audio/mp4" else "video/mp4"
            "m4a" -> "audio/mp4"
            "mp3" -> "audio/mpeg"
            "webm" -> if (audio) "audio/webm" else "video/webm"
            "mkv" -> "video/x-matroska"
            "opus", "ogg" -> "audio/ogg"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            else -> if (audio) "audio/*" else "video/*"
        }

    private fun needsStoragePermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED

    private fun requestStoragePermission(result: MethodChannel.Result) {
        if (!needsStoragePermission()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), STORAGE_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == STORAGE_REQUEST) {
            pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }

    // ---------- Compartir y abrir ----------

    /** [title]: título del selector, en el idioma de la app. */
    private fun share(uri: String, mime: String, title: String?): Boolean {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, Uri.parse(uri))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return tryStart(Intent.createChooser(send, title ?: "Share"))
    }

    private fun openWith(uri: String, mime: String, title: String?): Boolean {
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(uri), mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return tryStart(Intent.createChooser(view, title ?: "Open with"))
    }

    private fun tryStart(intent: Intent): Boolean =
        try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }

    // ---------- Sesión de Instagram / Facebook ----------

    /**
     * Copia las cookies del WebView (donde el usuario inició sesión) a un archivo
     * cookies.txt que yt-dlp entiende. Devuelve true si existe la cookie [required]
     * (por ejemplo "sessionid" en Instagram), es decir, si la sesión está abierta.
     */
    private fun saveCookies(domain: String, required: String): Boolean {
        val manager = CookieManager.getInstance()
        manager.flush()
        val raw = manager.getCookie("https://www.$domain") ?: return false
        val pairs = raw.split(";").map { it.trim() }.filter { it.contains('=') }
        if (pairs.none { it.startsWith("$required=") }) return false

        val expiry = System.currentTimeMillis() / 1000 + 365L * 24 * 3600
        val text = buildString {
            append("# Netscape HTTP Cookie File\n")
            for (pair in pairs) {
                val i = pair.indexOf('=')
                append(".$domain\tTRUE\t/\tTRUE\t$expiry\t${pair.substring(0, i)}\t${pair.substring(i + 1)}\n")
            }
        }
        Engine.cookieFile(applicationContext, domain).writeText(text)
        return true
    }

    private fun clearCookies(domain: String) {
        Engine.cookieFile(applicationContext, domain).delete()
        val manager = CookieManager.getInstance()
        val url = "https://www.$domain"
        manager.getCookie(url)?.split(";")?.forEach { pair ->
            val name = pair.substringBefore('=').trim()
            if (name.isNotEmpty()) {
                manager.setCookie(url, "$name=; Max-Age=0; Domain=.$domain; Path=/")
            }
        }
        manager.flush()
    }

    companion object {
        private const val STORAGE_REQUEST = 4021
    }
}

/** Uso de yt-dlp. Cada descarga se guarda primero en la caché de la app. */
object Engine {
    @Volatile
    private var ready = false

    @Synchronized
    fun ensureInit(context: Context) {
        if (ready) return
        YoutubeDL.getInstance().init(context)
        FFmpeg.getInstance().init(context)
        ready = true
    }

    fun version(context: Context): String? = YoutubeDL.getInstance().versionName(context)

    /** Actualiza yt-dlp desde GitHub. Devuelve "done" o "up_to_date". */
    fun update(context: Context): String {
        ensureInit(context)
        val status = YoutubeDL.getInstance().updateYoutubeDL(context, YoutubeDL.UpdateChannel.STABLE)
        return if (status == YoutubeDL.UpdateStatus.DONE) "done" else "up_to_date"
    }

    fun cookieFile(context: Context, domain: String): File =
        File(File(context.filesDir, "cookies").apply { mkdirs() }, "$domain.txt")

    private fun addCookies(context: Context, request: YoutubeDLRequest, domain: String?) {
        if (domain == null) return
        val file = cookieFile(context, domain)
        if (file.exists()) request.addOption("--cookies", file.absolutePath)
    }

    /** JSON de yt-dlp (-J). Con [playlist] lista los videos de un perfil o lista sin descargarlos. */
    fun getInfo(context: Context, url: String, playlist: Boolean, cookies: String?): String {
        ensureInit(context)
        val request = YoutubeDLRequest(url)
        request.addOption("-J")
        if (playlist) {
            request.addOption("--flat-playlist")
            request.addOption("--playlist-end", 60)
        } else {
            request.addOption("--no-playlist")
        }
        addCookies(context, request, cookies)
        // Con los 4 argumentos se elige sin ambigüedad una de las dos versiones de execute().
        return YoutubeDL.getInstance().execute(request, null, false, null).out
    }

    /** Descarga y devuelve la ruta del archivo final. */
    fun download(
        context: Context,
        id: String,
        url: String,
        args: List<String>,
        cookies: String?,
        onProgress: (Float, Long, String) -> Unit,
    ): String {
        ensureInit(context)
        val dir = File(context.cacheDir, "descargas/$id")
        dir.deleteRecursively()
        dir.mkdirs()

        val request = YoutubeDLRequest(url)
        request.addOption("--no-playlist")
        request.addOption("--no-mtime")
        request.addOption("--windows-filenames")
        request.addOption("--newline")
        request.addOption("-o", dir.absolutePath + "/%(title).60B [%(id)s].%(ext)s")
        addCookies(context, request, cookies)
        if (args.isNotEmpty()) request.addCommands(args)

        try {
            YoutubeDL.getInstance().execute(request, id, false, onProgress)
        } catch (e: Throwable) {
            dir.deleteRecursively()
            throw e
        }

        val file = dir.listFiles()
            ?.filter { it.isFile && !it.name.endsWith(".part") && !it.name.endsWith(".ytdl") }
            ?.maxByOrNull { it.length() }
            ?: throw IOException("La descarga terminó pero no se encontró el archivo")
        return file.absolutePath
    }
}
