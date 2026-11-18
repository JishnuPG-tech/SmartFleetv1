package com.smartfleet.app.smartfleet_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smartfleet.app/installer"
    private val REQUEST_INSTALL_PERMISSION = 8801
    private var pendingApkPath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path is null or empty", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                        return@setMethodCallHandler
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            pendingApkPath = filePath
                            val manageIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivityForResult(manageIntent, REQUEST_INSTALL_PERMISSION)
                            result.success(false)
                            return@setMethodCallHandler
                        }
                    }

                    val launched = launchInstaller(file)
                    result.success(launched)
                }
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val manageIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivityForResult(manageIntent, REQUEST_INSTALL_PERMISSION)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchInstaller(file: File): Boolean {
        return try {
            val authority = applicationContext.packageName + ".fileprovider"
            val apkUri: Uri = FileProvider.getUriForFile(context, authority, file)

            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.grantUriPermission("com.google.android.packageinstaller", apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            context.grantUriPermission("com.android.packageinstaller", apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

            startActivity(installIntent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    override fun onResume() {
        super.onResume()
        checkAndResumePendingInstall()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_INSTALL_PERMISSION) {
            checkAndResumePendingInstall()
        }
    }

    private fun checkAndResumePendingInstall() {
        val path = pendingApkPath ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (packageManager.canRequestPackageInstalls()) {
                pendingApkPath = null
                val file = File(path)
                if (file.exists()) {
                    launchInstaller(file)
                    methodChannel?.invokeMethod("onInstallResumed", mapOf("success" to true))
                }
            }
        } else {
            pendingApkPath = null
            val file = File(path)
            if (file.exists()) {
                launchInstaller(file)
                methodChannel?.invokeMethod("onInstallResumed", mapOf("success" to true))
            }
        }
    }
}
