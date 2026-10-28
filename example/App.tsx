import { Platform, StatusBar, StyleSheet, Text, View } from 'react-native';

// Nothing to see here. The green line comes from expo-crack being installed, no code needed.
export default function App() {
  return (
    <View style={styles.screen}>
      <StatusBar barStyle="dark-content" />
      <Text style={styles.title} numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.5}>
        npx expo install expo-crack
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#ffffff',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  title: {
    fontSize: 32,
    fontWeight: '600',
    color: '#111111',
    fontFamily: Platform.select({ ios: 'Menlo', android: 'monospace', default: 'monospace' }),
  },
});
