package com.example.rodex_movil

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "rodex/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                // Abre WhatsApp con el chat del número indicado y el archivo adjunto
                // (el usuario solo toca "Enviar"). Devuelve false si WhatsApp no está
                // instalado, para que Dart use el compartir genérico.
                "sendFile" -> {
                    val path = call.argument<String>("path")
                    val phone = call.argument<String>("phone")
                    val text = call.argument<String>("text") ?: ""
                    val mime = call.argument<String>("mime") ?: "application/pdf"
                    if (path == null || phone == null) {
                        result.error("args", "path y phone son obligatorios", null)
                        return@setMethodCallHandler
                    }
                    result.success(sendFileToWhatsApp(File(path), phone, text, mime))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendFileToWhatsApp(file: File, phone: String, text: String, mime: String): Boolean {
        if (!file.exists()) return false
        // Reutiliza el FileProvider de share_plus (cubre .../cache/share_plus/).
        val uri = FileProvider.getUriForFile(this, "$packageName.flutter.share_provider", file)
        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                // Preselecciona el chat del destinatario (número internacional sin '+').
                putExtra("jid", "$phone@s.whatsapp.net")
                setPackage(pkg)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // probar el siguiente paquete
            }
        }
        return false
    }
}
