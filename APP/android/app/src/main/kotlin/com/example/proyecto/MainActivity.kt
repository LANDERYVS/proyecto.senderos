package com.example.proyecto

import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				if (call.method != "copyIncomingGpx") {
					result.notImplemented()
					return@setMethodCallHandler
				}

				try {
					val uri = call.arguments as? String
						?: throw IllegalArgumentException("Falta el URI del archivo")
					result.success(copyIncomingGpx(uri))
				} catch (error: Exception) {
					result.error("GPX_READ_FAILED", error.message, null)
				}
			}
	}

	private fun copyIncomingGpx(rawUri: String): String {
		val uri = Uri.parse(rawUri)
		val displayName = if (uri.scheme == "content") {
			contentResolver.query(uri, null, null, null, null)?.use { cursor ->
				val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
				if (nameColumn >= 0 && cursor.moveToFirst()) cursor.getString(nameColumn) else null
			}
		} else {
			uri.lastPathSegment
		}
		val fileName = displayName ?: "sendero.gpx"
		if (!fileName.substringBefore('?').lowercase().endsWith(".gpx")) {
			throw IllegalArgumentException("El archivo seleccionado no es GPX")
		}

		val input = when (uri.scheme) {
			"content" -> contentResolver.openInputStream(uri)
			"file" -> uri.path?.let { File(it).inputStream() }
			else -> null
		} ?: throw IllegalArgumentException("No se pudo abrir el archivo")

		val safeName = fileName.replace(Regex("[^A-Za-z0-9._-]"), "_")
		val destination = File(cacheDir, "incoming_gpx/${UUID.randomUUID()}_$safeName")
		destination.parentFile?.mkdirs()
		input.use { source ->
			destination.outputStream().use { output -> source.copyTo(output) }
		}
		if (destination.length() == 0L) {
			destination.delete()
			throw IllegalArgumentException("El archivo GPX está vacío")
		}
		return destination.absolutePath
	}

	private companion object {
		const val CHANNEL = "proyecto.senderos/gpx_files"
	}
}
