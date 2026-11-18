class InfoContent {
  const InfoContent(this.title, this.paragraphs);
  final String title;
  final List<String> paragraphs;
}

const infoPages = <String, InfoContent>{
  'about': InfoContent('About KEEPON', [
    'KEEPON helps protect your Android phone against unauthorized handling and theft. It watches for movement, charger removal, headphone disconnection and SIM changes, sounds an alarm, and keeps a history of what happened.',
    'KEEPON complements Android\'s built-in security. It does not replace it, and it cannot guarantee that a stolen phone is recovered.',
    'Some manufacturers limit background apps. If protection stops unexpectedly, set KEEPON\'s battery use to unrestricted in Android settings.',
  ]),
  'privacy': InfoContent('Privacy', [
    'KEEPON stores its settings, activity history and last saved location only on this device.',
    'KEEPON does not create an account, does not send your data to any server, and has no analytics or ads.',
    'Location is read when you tap "Update location" in Recovery, and, if you allow it in Settings, it is recorded during an alarm session. Recorded locations are encrypted and kept only on this phone. KEEPON does not send them anywhere.',
    'Location is read only when you tap "Update location now" in Device Recovery. KEEPON never turns on the microphone or camera, and never records people nearby.',
    'You can delete the activity history from the Activity tab, and everything KEEPON stores is removed when you uninstall the app.',
    'This is a plain-language summary for development builds. A full privacy policy must be published before any public release.',
  ]),
  'terms': InfoContent('Terms and conditions', [
    'KEEPON is provided as is. It is a helper tool and does not guarantee detection of every theft attempt or recovery of a lost phone.',
    'Do not put yourself at risk to recover a phone. Contact local authorities if you believe it was stolen.',
    'The final legal terms must be written and published before any public release. This text is a development placeholder.',
  ]),
  'credits': InfoContent('Credits', [
    'KEEPON icon set and logo: KEEPON brand sheet.',
    'Animated icons: Flaticon (flaticon.com). Add the exact author credit shown on each download here before publishing.',
    'Lottie animation playback: the open-source lottie package for Flutter.',
  ]),
  'support': InfoContent('Support', [
    'A public support contact has not been set up yet for this development build.',
    'If something does not work, note your phone model, Android version and what you expected, and report it to the developer of this build.',
  ]),
};
