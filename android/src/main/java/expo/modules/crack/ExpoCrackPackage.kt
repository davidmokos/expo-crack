package expo.modules.crack

import android.app.Activity
import android.content.Context
import android.os.Bundle
import expo.modules.core.interfaces.Package
import expo.modules.core.interfaces.ReactActivityLifecycleListener

/** Turns the crack on when the activity is created, before any JavaScript runs. Installing the package is enough. */
class ExpoCrackPackage : Package {
  override fun createReactActivityLifecycleListeners(activityContext: Context): List<ReactActivityLifecycleListener> {
    return listOf(ExpoCrackActivityLifecycleListener())
  }
}

class ExpoCrackActivityLifecycleListener : ReactActivityLifecycleListener {
  override fun onCreate(activity: Activity, savedInstanceState: Bundle?) {
    if (CrackOverlay.autoStartEnabled(activity)) {
      CrackOverlay.setEnabled(activity, true)
    }
  }

  override fun onResume(activity: Activity) {
    CrackOverlay.attach(activity)
  }

  override fun onDestroy(activity: Activity) {
    CrackOverlay.onActivityDestroyed(activity)
  }
}
