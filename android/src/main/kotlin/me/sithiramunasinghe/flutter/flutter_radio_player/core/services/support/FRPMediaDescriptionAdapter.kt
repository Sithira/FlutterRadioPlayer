package me.sithiramunasinghe.flutter.flutter_radio_player.core.services.support

import android.app.PendingIntent
import android.graphics.Bitmap
import android.os.Build
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.ui.PlayerNotificationManager
import io.flutter.Log
import me.sithiramunasinghe.flutter.flutter_radio_player.core.data.FRPIcyMetaData
import me.sithiramunasinghe.flutter.flutter_radio_player.core.services.FRPCoreService

class FRPMediaDescriptionAdapter(private val frpCoreService: FRPCoreService) :
    PlayerNotificationManager.MediaDescriptionAdapter {

    companion object {
        private const val TAG = "FRPMediaDescriptionAdapter"
    }

    override fun getCurrentContentTitle(player: Player): CharSequence {
        if (frpCoreService.mediaSourceList.isEmpty()) {
            Log.i(TAG, "MediaList isEmpty")
            return "N/A"
        }
        Log.i(
            TAG,
            "Active title from media-source list = ${frpCoreService.mediaSourceList[player.currentMediaItemIndex].title}"
        )
        return frpCoreService.mediaSourceList[player.currentMediaItemIndex].title!!
    }

    override fun createCurrentContentIntent(player: Player): PendingIntent? {
        if (frpCoreService.currentActivity == null) {
            Log.i(TAG, "Ignoring pending intent temporary...")
            return null
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.getActivity(
                frpCoreService.context.applicationContext,
                0,
                frpCoreService.currentActivity?.intent,
                PendingIntent.FLAG_MUTABLE
            )
        } else {
            PendingIntent.getActivity(
                frpCoreService.context,
                0,
                frpCoreService.currentActivity?.intent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
    }

    override fun getCurrentContentText(player: Player): CharSequence {
        val parsedMeta = FRPIcyMetaData(meta = frpCoreService.currentMetaData)

        if (frpCoreService.mediaSourceList.isEmpty()) {
            return "N/A"
        }

        val descriptionFromSource: String =
            frpCoreService.mediaSourceList[player.currentMediaItemIndex]
                .description!!

        if (!frpCoreService.useICYData) {
            return descriptionFromSource
        }

        return if (parsedMeta.title == null) descriptionFromSource
        else parsedMeta.title!!
    }

    override fun getCurrentLargeIcon(
        player: Player,
        callback: PlayerNotificationManager.BitmapCallback
    ): Bitmap? {
        return null
    }
}