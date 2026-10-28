package expo.modules.glitch

import android.app.Activity
import android.content.Context
import android.os.Bundle
import expo.modules.core.interfaces.Package
import expo.modules.core.interfaces.ReactActivityLifecycleListener

/** Turns the glitch on when the activity is created, before any JavaScript runs. Installing the package is enough. */
class ExpoGlitchPackage : Package {
  override fun createReactActivityLifecycleListeners(activityContext: Context): List<ReactActivityLifecycleListener> {
    return listOf(ExpoGlitchActivityLifecycleListener())
  }
}

class ExpoGlitchActivityLifecycleListener : ReactActivityLifecycleListener {
  override fun onCreate(activity: Activity, savedInstanceState: Bundle?) {
    if (GlitchOverlay.autoStartEnabled(activity)) {
      GlitchOverlay.setEnabled(activity, true)
    }
  }

  override fun onResume(activity: Activity) {
    GlitchOverlay.attach(activity)
  }

  override fun onDestroy(activity: Activity) {
    GlitchOverlay.onActivityDestroyed(activity)
  }
}
