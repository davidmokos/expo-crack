import Crack, { CrackSide } from 'expo-crack';
import { useEffect, useState } from 'react';
import { Platform, Pressable, StatusBar, StyleSheet, Switch, Text, View, useWindowDimensions } from 'react-native';

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const SIDES: CrackSide[] = ['left', 'right', 'full'];

function useClock() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);
  return now;
}

export default function App() {
  const now = useClock();
  const { width, height } = useWindowDimensions();
  const [enabled, setEnabled] = useState(() => Crack.isEnabled());
  const [crease, setCrease] = useState(false);
  const [flicker, setFlicker] = useState(true);
  const [side, setSide] = useState<CrackSide>('right');

  useEffect(() => {
    Crack.configure({ crease, flicker, side });
  }, [crease, flicker, side]);

  const hours = now.getHours() % 12 || 12;
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const date = `${DAYS[now.getDay()]} ${MONTHS[now.getMonth()]} ${now.getDate()}`;

  return (
    <View style={styles.screen}>
      <StatusBar barStyle="light-content" />
      <View style={[styles.blob, styles.blobA]} />
      <View style={[styles.blob, styles.blobB]} />

      <View style={styles.clock}>
        <Text style={styles.date}>{date}</Text>
        <Text style={styles.time}>
          {hours}:{minutes}
        </Text>
        <Text style={styles.caption}>Your iPhone Duo, now with the authentic green line.</Text>
      </View>

      <View style={styles.panel}>
        <Row
          label="Green line"
          value={enabled}
          onChange={(value) => {
            if (value) {
              Crack.enable();
            } else {
              Crack.disable();
            }
            setEnabled(value);
          }}
        />
        <Row label="Fold crease" value={crease} onChange={setCrease} />
        <Row label="Flicker" value={flicker} onChange={setFlicker} />

        <View style={styles.segments}>
          {SIDES.map((option) => {
            const active = option === side;
            return (
              <Pressable
                key={option}
                onPress={() => setSide(option)}
                style={[styles.segment, active && styles.segmentActive]}>
                <Text style={[styles.segmentText, active && styles.segmentTextActive]}>{option}</Text>
              </Pressable>
            );
          })}
        </View>

        <Text style={styles.footer}>
          npx expo install expo-crack · {Math.round(width)} × {Math.round(height)} pt
        </Text>
      </View>
    </View>
  );
}

function Row({ label, value, onChange }: { label: string; value: boolean; onChange: (value: boolean) => void }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Switch
        value={value}
        onValueChange={onChange}
        trackColor={{ true: '#2fb88f', false: 'rgba(255,255,255,0.15)' }}
        thumbColor="#ffffff"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#0e0f1a',
    paddingTop: 84,
    paddingBottom: 48,
    paddingHorizontal: 24,
    justifyContent: 'space-between',
    alignItems: 'center',
    overflow: 'hidden',
  },
  blob: {
    position: 'absolute',
    borderRadius: 999,
  },
  blobA: {
    width: 420,
    height: 420,
    top: -140,
    left: -120,
    backgroundColor: '#2e3270',
    opacity: 0.5,
  },
  blobB: {
    width: 560,
    height: 560,
    bottom: -260,
    right: -200,
    backgroundColor: '#4a2f6b',
    opacity: 0.45,
  },
  clock: {
    alignItems: 'center',
  },
  date: {
    fontSize: 20,
    fontWeight: '600',
    color: '#c9cbe3',
  },
  time: {
    fontSize: 128,
    lineHeight: 140,
    fontWeight: '200',
    color: '#e8e9f5',
    letterSpacing: -4,
    fontVariant: ['tabular-nums'],
  },
  caption: {
    marginTop: 8,
    fontSize: 15,
    color: '#8d90b0',
    textAlign: 'center',
  },
  panel: {
    width: '100%',
    maxWidth: 420,
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderRadius: 24,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.14)',
    padding: 20,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
  },
  rowLabel: {
    fontSize: 17,
    color: '#e8e9f5',
  },
  segments: {
    flexDirection: 'row',
    marginTop: 10,
    padding: 3,
    borderRadius: 12,
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
  segment: {
    flex: 1,
    paddingVertical: 8,
    borderRadius: 9,
    alignItems: 'center',
  },
  segmentActive: {
    backgroundColor: '#61ffcc',
  },
  segmentText: {
    fontSize: 15,
    fontWeight: '600',
    color: '#c9cbe3',
    textTransform: 'capitalize',
  },
  segmentTextActive: {
    color: '#0e0f1a',
  },
  footer: {
    marginTop: 16,
    fontSize: 12,
    color: '#6b6e8c',
    textAlign: 'center',
    fontFamily: Platform.select({ ios: 'Menlo', android: 'monospace', default: 'monospace' }),
  },
});
