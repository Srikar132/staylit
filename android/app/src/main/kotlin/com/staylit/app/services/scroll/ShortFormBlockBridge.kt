package com.staylit.app.services.scroll

import android.content.Context
import android.util.Log
import com.staylit.app.managers.ShortFormBlockManager
import com.staylit.app.services.shared.BlockingConfig

/**
 * Switches a short-form block ON from the native side ("Take a break").
 *
 * Two native stores hold the toggles and both are written, exactly like the Blocks tab does through Dart:
 * [ShortFormBlockManager] (what the accessibility service gate reads) and [BlockingConfig] (the persistent
 * config). Firestore, which the Blocks tab shows, is updated by Flutter when it pulls the answer log.
 */
object ShortFormBlockBridge {

    private const val TAG = "ScrollDamage"

    fun enable(context: Context, info: ShortFormInfo) {
        try {
            ShortFormBlockManager.getInstance(context).setShortFormBlock(info.platform, info.feature, true)

            val config = BlockingConfig.getInstance(context)
            val blocks = config.getPersistentShortFormConfig().toMutableMap()
            blocks["${info.platform}_${info.feature}"] = mapOf(
                "platform" to info.platform,
                "feature" to info.feature,
                "isBlocked" to true,
            )
            config.setPersistentShortFormConfig(blocks)
            config.setPersistentShortFormBlocking(true)
            Log.d(TAG, "block on pkg=${info.pkg}")
        } catch (e: Exception) {
            Log.e(TAG, "could not switch the block on", e)
        }
    }
}
