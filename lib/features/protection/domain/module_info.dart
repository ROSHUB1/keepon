import '../../../shared/models/protection_config.dart';

class ModuleInfo {
  const ModuleInfo({
    required this.id,
    required this.title,
    required this.summary,
    required this.howItWorks,
    required this.limitations,
    required this.permissionNote,
  });

  final ModuleId id;
  final String title;
  final String summary;
  final String howItWorks;
  final String limitations;
  final String permissionNote;
}

const _modules = <ModuleId, ModuleInfo>{
  ModuleId.motion: ModuleInfo(
    id: ModuleId.motion,
    title: 'Motion Detection',
    summary: 'Sounds an alarm when your phone is moved or picked up.',
    howItWorks:
        'Uses the accelerometer. After you turn protection on, KEEPON waits 10 seconds so you can put the phone down, then watches for sustained movement. Higher sensitivity reacts to smaller movements but can cause false alarms on a moving vehicle or in a bag.',
    limitations:
        'While motion detection is on, KEEPON keeps the processor awake so the sensor keeps working with the screen off. This uses extra battery. Some phone makers stop background apps; set KEEPON\'s battery use to unrestricted for best results.',
    permissionNote: 'No permission is needed for the accelerometer. Notifications are needed to see the alarm Stop button.',
  ),
  ModuleId.charger: ModuleInfo(
    id: ModuleId.charger,
    title: 'Charger Alert',
    summary: 'Alerts when the charger is unplugged.',
    howItWorks:
        'Listens for Android\'s "power disconnected" signal while the monitoring service runs. It only reacts to a disconnection that happens after protection is on.',
    limitations:
        'Some wireless chargers and docks do not report a clean disconnection. If the phone was not charging when protection started, nothing will be reported until it is plugged in and unplugged again.',
    permissionNote: 'No special permission is needed.',
  ),
  ModuleId.headphones: ModuleInfo(
    id: ModuleId.headphones,
    title: 'Headphone Alert',
    summary: 'Alerts when wired or Bluetooth headphones disconnect.',
    howItWorks:
        'Watches Android\'s audio-device list for wired, USB and Bluetooth headsets being removed. Several signals from the same headset within 2 seconds are merged into one alert.',
    limitations:
        'Walking out of Bluetooth range also counts as a disconnection. Some accessories (speakers, car kits) are not treated as headphones by Android.',
    permissionNote: 'No special permission is needed.',
  ),
  ModuleId.sim: ModuleInfo(
    id: ModuleId.sim,
    title: 'SIM Monitoring',
    summary: 'Alerts when the SIM card is removed or locked.',
    howItWorks:
        'Reads the SIM state Android reports for each slot and compares it with the state seen when protection started. A removed SIM raises the alarm; other changes (locked, inserted) are recorded.',
    limitations:
        'Android does not let normal apps read SIM serial numbers or phone numbers, so KEEPON only sees the card state. Some phones report SIM changes late or only after a restart. Unavailable on devices without telephony.',
    permissionNote: 'No permission is needed to read the SIM state.',
  ),
  ModuleId.connectivity: ModuleInfo(
    id: ModuleId.connectivity,
    title: 'Network Drop',
    summary: 'Alerts when the phone loses all network, or when airplane mode is turned on.',
    howItWorks:
        'Checks for an active network every 5 seconds. If there is none for 20 seconds, or airplane mode is switched on, KEEPON treats it as a possible attempt to cut the phone off.',
    limitations:
        'Normal coverage gaps (elevators, basements, rural areas) can also trigger it. A thief who turns the phone off completely will not be detected by this module.',
    permissionNote: 'No special permission is needed. Network state is read only.',
  ),
};

ModuleInfo moduleInfo(ModuleId id) => _modules[id]!;
