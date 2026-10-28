const { AndroidConfig, createRunOncePlugin, withAndroidManifest, withInfoPlist } = require('expo/config-plugins');

const pkg = require('./package.json');

/**
 * Optional. The green line is on by default; add the plugin with `{ "autoStart": false }` to make your app
 * start without it and turn it on from JavaScript instead.
 *
 *   "plugins": [["expo-crack", { "autoStart": false }]]
 */
const withExpoCrack = (config, { autoStart = true } = {}) => {
  config = withInfoPlist(config, (config) => {
    config.modResults.ExpoCrackAutoStart = Boolean(autoStart);
    return config;
  });
  config = withAndroidManifest(config, (config) => {
    const application = AndroidConfig.Manifest.getMainApplicationOrThrow(config.modResults);
    AndroidConfig.Manifest.addMetaDataItemToMainApplication(
      application,
      'expo.modules.crack.AUTO_START',
      String(Boolean(autoStart))
    );
    return config;
  });
  return config;
};

module.exports = createRunOncePlugin(withExpoCrack, pkg.name, pkg.version);
