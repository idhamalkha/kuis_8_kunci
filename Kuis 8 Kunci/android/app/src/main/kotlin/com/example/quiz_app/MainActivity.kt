package com.example.quiz_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.quiz_app/backend"
    private var backendProcess: Process? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBackend" -> {
                        try {
                            startBackendServer()
                            result.success("Backend started")
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "stopBackend" -> {
                        stopBackendServer()
                        result.success("Backend stopped")
                    }
                    "isBackendRunning" -> {
                        result.success(backendProcess?.isAlive == true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Start backend when app launches, but catch and log failures.
        try {
            startBackendServer()
        } catch (e: Exception) {
            android.util.Log.e("Backend", "Failed to auto-start backend on launch", e)
        }
    }

    @Throws(Exception::class)
    private fun startBackendServer() {
        if (backendProcess?.isAlive == true) {
            return // Already running
        }

        val assetManager = assets
        // Open the asset and inspect header to avoid trying to execute an incompatible binary
        val header = ByteArray(2)
        assetManager.open("quiz_api.exe").use { input ->
            val read = input.read(header, 0, 2)
            if (read == 2) {
                // 'M' 'Z' header indicates a Windows PE executable (not runnable on Android)
                if (header[0] == 0x4D.toByte() && header[1] == 0x5A.toByte()) {
                    throw Exception("Bundled backend is a Windows PE executable (quiz_api.exe). This binary cannot be executed on Android.")
                }
            }
        }

        // If header check passed, extract and attempt to start
        val inputStream = assetManager.open("quiz_api.exe")
        val exeFile = java.io.File(filesDir, "quiz_api.exe")

        inputStream.use { input ->
            exeFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        // Try to make executable and launch
        if (!exeFile.setExecutable(true)) {
            android.util.Log.w("Backend", "Failed to mark backend file executable: ${exeFile.absolutePath}")
        }

        val pb = ProcessBuilder(exeFile.absolutePath)
        pb.directory(filesDir)
        pb.inheritIO()
        backendProcess = pb.start()

        if (backendProcess?.isAlive == true) {
            android.util.Log.i("Backend", "Backend server started at ${exeFile.absolutePath}")
        } else {
            throw Exception("Failed to start backend process. See logs for details.")
        }
    }

    private fun stopBackendServer() {
        try {
            backendProcess?.destroy()
            backendProcess = null
        } catch (e: Exception) {
            android.util.Log.e("Backend", "Failed to stop backend", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopBackendServer()
    }
}
