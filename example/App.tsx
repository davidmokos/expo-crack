import { StatusBar, StyleSheet, Text, View } from 'react-native';

// Nothing to see here. The green line comes from expo-crack being installed, no code needed.
export default function App() {
  return (
    <View style={styles.screen}>
      <StatusBar barStyle="dark-content" />
      <Text style={styles.title}>expo-crack</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#ffffff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 44,
    fontWeight: '700',
    letterSpacing: -1,
    color: '#111111',
  },
});
