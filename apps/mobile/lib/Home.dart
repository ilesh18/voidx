import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'js_interop.dart';
import 'package:flutter_config/flutter_config.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:http/http.dart' as http;
import 'sos_chat_panel.dart';

String _safeBackendUrl() {
  try {
    final val = FlutterConfig.get('BACKEND_URL');
    if (val != null && val.toString().isNotEmpty) return val.toString();
  } catch (_) {}
  return 'http://172.25.179.250:8080';
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class SOSButton extends StatelessWidget {
  final bool isHelping;
  final double currentLat;
  final double currentLng;

  SOSButton({
    required this.isHelping,
    this.currentLat = 12.9806,
    this.currentLng = 80.2132,
  });

  @override
  Widget build(BuildContext context) {
    return (!isHelping)
        ? Positioned(
            bottom: 175.0,
            right: 16.0,
            child: FloatingActionButton(
              onPressed: () => _onSOSPressed(context),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: const Color.fromARGB(255, 250, 121, 121),
            ),
          )
        : SizedBox();
  }

  void _onSOSPressed(BuildContext context) {
    try {
      jsCall('setFlutterInteractive', [true]);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return SOSChatPanel(
          currentLat: currentLat,
          currentLng: currentLng,
          backendUrl: _safeBackendUrl(),
          onClose: () => Navigator.of(bc).pop(),
        );
      },
    );
  }

  void _sendSOS(BuildContext context) async {
    final String message = 'SOS! I need help with the climate crisis!';
    final String uri = 'sms:?body=${Uri.encodeQueryComponent(message)}';

    if (await canLaunch(uri)) {
      await launch(uri);
    } else {
      print('Could not launch $uri');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Could not launch messaging app')),
      );
    }
  }
}

class _HomeState extends State<Home> {
  double currentLat = 20.5937;
  double currentLng = 78.9629;
  bool locationLoaded = false;
  bool isHelping = false;
  bool isOffline = false;

  List<Map<String, dynamic>> _needItems = [];
  List<Map<String, dynamic>> _giveItems = [];

  Future<void> _checkConnectivity() async {
    final isConnected = await InternetConnectionChecker().hasConnection;
    setState(() {
      isOffline = !isConnected;
    });
  }

  List<Map<String, dynamic>> filtersNeedHelp = [
    {"type": "Hospital", "icon": FontAwesomeIcons.truckMedical},
    {"type": "Relief Camp", "icon": FontAwesomeIcons.tent},
    {"type": "Safe Space", "icon": FontAwesomeIcons.home},
    {"type": "Supplies", "icon": FontAwesomeIcons.boxOpen},
    {"type": "Volunteer", "icon": FontAwesomeIcons.handsHelping},
  ];

  List<Map<String, dynamic>> filtersGiveHelp = [
    {"type": "Victim", "icon": FontAwesomeIcons.handHoldingMedical},
    {"type": "Volunteer", "icon": FontAwesomeIcons.handsHelping},
    {"type": "Donate", "icon": FontAwesomeIcons.gift},
    {"type": "Shelter", "icon": FontAwesomeIcons.home},
    {"type": "Food", "icon": FontAwesomeIcons.utensils},
  ];

  String selectedFilter = '';

  @override
  void initState() {
    super.initState();
    _registerJsCallbacks();
    _getCurrentLocation();
    _loadModePreference();
    _loadJsonData();
    Timer.periodic(Duration(seconds: 5), (timer) {
      _checkConnectivity();
    });
  }

  void _registerJsCallbacks() {
    try {
      jsSet('flutterOpenDrawer', () {
        _showAssistanceDrawer();
      });
      jsSet('flutterSOS', () {
        if (!isHelping) {
          SOSButton(isHelping: isHelping)._onSOSPressed(context);
        }
      });
      jsSet('flutterRecenter', () {
        jsCall('updateWindyLocation', [currentLat, currentLng]);
      });
      jsSet('flutterAction', () {
        actionButtonClickFn();
      });
      jsCall('setFlutterInteractive', [false]);
    } catch (e) {
      debugPrint('Error registering JS callbacks: $e');
    }
  }

  void _getCurrentLocation() async {
    try {
      var position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentLat = position.latitude;
        currentLng = position.longitude;
        locationLoaded = true;
      });
      // Update Windy map in the HTML background via JS
      jsCall('updateWindyLocation', [currentLat, currentLng]);
      _loadJsonData();
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        locationLoaded = true;
      });
    }
  }

  Future<void> _loadJsonData() async {
    final url = Uri.parse('${_safeBackendUrl()}/api/v1/?lat=$currentLat&lng=$currentLng');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // final jsonResponse = json.decode(response.body);
        final jsonResponse = json
            .decode(response.body.replaceAll('\n', '').replaceAll('  ', ''));
        print(jsonResponse);
        _processJsonData(jsonResponse);
      } else {
        print(
            'Failed to load data from the internet. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  void _processJsonData(Map<String, dynamic> data) {
    setState(() {
      _needItems = List<Map<String, dynamic>>.from(data['need'] ?? []);
      _giveItems = List<Map<String, dynamic>>.from(data['give'] ?? []);
    });
  }

  void _showLocationDetails(
      BuildContext context, Map<String, dynamic> locationDetails) async {
    try {
      jsCall('setFlutterInteractive', [true]);
    } catch (_) {}
    try {
      final double startLatitude = currentLat;
      final double startLongitude = currentLng;
      final location = locationDetails['location'] as Map<String, dynamic>?;
      final double endLatitude =
          (location?['lat'] as num?)?.toDouble() ?? currentLat;
      final double endLongitude =
          (location?['lng'] as num?)?.toDouble() ?? currentLng;

      double distanceInMeters = Geolocator.distanceBetween(
          startLatitude, startLongitude, endLatitude, endLongitude);
      String distanceDisplay = distanceInMeters < 1000
          ? '${distanceInMeters.toStringAsFixed(0)}m'
          : '${(distanceInMeters / 1000).toStringAsFixed(1)}km';

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext bc) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationDetails['type'].toString().toUpperCase(),
                    style: GoogleFonts.getFont(
                      "Lexend",
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Divider(thickness: 2),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.place, color: Colors.black),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Distance: $distanceDisplay',
                          style: GoogleFonts.getFont(
                            "Lexend",
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _openMapRoute(startLatitude, startLongitude,
                              endLatitude, endLongitude);
                        },
                        icon: Icon(Icons.directions, color: Colors.blue),
                        label: Text(
                          'Route',
                          style:
                              GoogleFonts.getFont("Lexend", color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.telegram, color: Colors.black),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ph: ${locationDetails['phone']}',
                          style: GoogleFonts.getFont(
                            "Lexend",
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            launch('tel:${locationDetails['phone']}'),
                        icon: Icon(Icons.call, color: Colors.blue),
                        label: Text(
                          ' Call ',
                          style:
                              GoogleFonts.getFont("Lexend", color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  Text(
                    locationDetails['type'] == 'victim'
                        ? 'Needs:'
                        : 'Available Assistance:',
                    //'Available Assistance:',
                    style: GoogleFonts.getFont(
                      "Lexend",
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  ...locationDetails['help'].map<Widget>((helpItem) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '• $helpItem',
                        style: GoogleFonts.getFont(
                          "Lexend",
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      try {
        jsCall('setFlutterInteractive', [false]);
      } catch (_) {}
    }
  }

  void _openMapRoute(
      double startLat, double startLng, double endLat, double endLng) async {
    String googleMapsUrl =
        "https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng&travelmode=driving";
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not open the map.';
    }
  }

  Future<void> _handleOfflineMode() async {
    if (isOffline) {
      while (isOffline) {
        await Future.delayed(Duration(hours: 2));
        final smsNumber = FlutterConfig.get('SMS_NUMBER');
        final lat = currentLat;
        final lng = currentLng;
        final message = 'offline $lat $lng';
        launch('sms:$smsNumber?body=$message');
        final response = await _waitForResponse(smsNumber);
        final jsonData = _combineJsonData(response);
        _processJsonData(jsonData);
      }
    }
  }

  void _loadModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isHelping = prefs.getBool('mode') ?? false;
    });
  }

  Future<List<String>> _waitForResponse(String smsNumber) async {
    final List<String> messages = [];
    final Telephony telephony = Telephony.instance;
    List<SmsMessage> smsStream = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY],
        filter: SmsFilter.where(SmsColumn.ADDRESS)
            .equals("$smsNumber")
            .and(SmsColumn.BODY)
            .like(""),
        sortOrder: [
          OrderBy(SmsColumn.ADDRESS, sort: Sort.ASC),
          OrderBy(SmsColumn.BODY)
        ]);

    await Future.delayed(Duration(minutes: 1));
    smsStream.isEmpty ? print('No messages') : print('Messages found');
    return messages;
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    List<Map<String, dynamic>> items = isHelping ? _giveItems : _needItems;
    if (selectedFilter.isEmpty) return items;
    return items.where((item) {
      String type = (item['type'] ?? '').toString().toLowerCase();
      return type == selectedFilter.toLowerCase();
    }).toList();
  }

  Map<String, dynamic> _combineJsonData(List<String> messages) {
    final Map<String, dynamic> combinedJson = {};
    final RegExp numberRegex = RegExp(r'^(\d+)-end$');
    final Map<int, String> orderedMessages = {};

    for (final message in messages) {
      final match = numberRegex.firstMatch(message);
      if (match != null) {
        final int number = int.parse(match.group(1)!);
        orderedMessages[number] = message;
      }
    }

    final List<String> orderedData = orderedMessages.values.toList();
    for (final data in orderedData) {
      final jsonData = jsonDecode(data);
      combinedJson.addAll(jsonData);
    }

    return combinedJson;
  }

  // Set<Circle> _buildCircles() {
  //   return {
  //     Circle(
  //       circleId: CircleId('current_location'),
  //       center: currentLocation,
  //       radius: 200,
  //       fillColor: Colors.green.withOpacity(0.5),
  //       strokeColor: Colors.green[800]!,
  //       strokeWidth: 3,
  //     ),
  //   };
  // }

  // Set<Marker> _buildMarkers() {
  //   return {
  //     if (currentCameraPosition.zoom < 10)
  //       Marker(
  //         markerId: MarkerId('current_location_marker'),
  //         position: currentLocation,
  //       ),
  //   };
  // }

  //<--------------------- Misc --------------------->
  // void _toggleMode(bool value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     isHelping = value;
  //     print(isHelping);
  //     prefs.setBool('mode', isHelping);
  //   });
  // }

  // <--------------------- Actions --------------------->

  // dynamic actionButtonClickFn() {
  //   // Placeholder function to print the details
  //   print("-------------------------------------------------------------------------------------------------");
  //   print('Current Location: $currentLocation');
  //   print('Selected Filter: $selectedFilter');
  //   print('Selected Mode: ${isHelping ? "Helping" : "Need Help"}');

  // }

  // -----------------------------------------------------------------------------------------------------------------------------------------------

  void makePostRequest(List<String> selectedHelp, bool isHelping, dynamic lat,
      dynamic lng) async {
    final prefs = await SharedPreferences.getInstance();
    String phoneNumber =
        prefs.getString('phoneNumber') ?? 'No phone number set';

    String mode = isHelping ? "give" : "need";
    String type = isHelping ? "volunteer" : "victim";
    double latitude = lat;
    double longitude = lng;

    Map<String, dynamic> requestBody = {
      "mode": mode,
      "type": type,
      "location": {"lat": latitude, "lng": longitude},
      "phone": phoneNumber,
      "help": selectedHelp,
    };

    final response = await http.post(
      Uri.parse(_safeBackendUrl() + "/api/v1"),
      headers: <String, String>{
        'Content-Type': 'application/json;',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      // Request successful
      print('POST request successful');
      print('Response: ${response.body}');
    } else {
      // Request failed
      print('POST request failed with status: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  }

  void reloadMapMarkers() async {
    await _loadJsonData();
  }

  void actionButtonClickFn() async {
    try {
      jsCall('setFlutterInteractive', [true]);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      String phoneNumber =
          prefs.getString('phoneNumber') ?? 'No phone number set';

      Map<String, IconData> needHelpIcons = {
        'Medical': Icons.medical_services,
        'Rescue & Evacuation': Icons.emergency,
        'Shelter': Icons.house,
        'Food & Rations': Icons.fastfood,
        'Clean Water': Icons.water_drop,
        'Clothing': Icons.checkroom,
        'Power & Charging': Icons.bolt,
        'Other': Icons.help_outline,
      };

      Map<String, IconData> giveHelpIcons = {
        'Volunteer': Icons.volunteer_activism,
        'Donate Supplies': Icons.monetization_on,
        'Provide Shelter': Icons.house,
        'Offer Food & Water': Icons.food_bank,
        'Medical Assistance': Icons.medical_services,
        'Rescue / Boat Unit': Icons.directions_boat,
      };

      Map<String, IconData> activeIcons =
          isHelping ? giveHelpIcons : needHelpIcons;

      Map<String, bool> helpOptions = {
        for (var item in activeIcons.keys) item: false,
      };

      bool isAnyOptionSelected() {
        return helpOptions.containsValue(true);
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
        ),
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(height: 10),
                    Text(
                      isHelping ? ' I can provide' : ' I need',
                      style: GoogleFonts.getFont(
                        "Lexend",
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Divider(),
                    ...helpOptions.keys.map((option) {
                      final isSelected = helpOptions[option]!;
                      return Container(
                        margin: EdgeInsets.only(top: 10),
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              helpOptions[option] = !isSelected;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              border: isSelected
                                   ? Border.all(
                                       color: Theme.of(context).primaryColor,
                                       width: 2)
                                   : Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 15),
                                Icon(activeIcons[option],
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: GoogleFonts.getFont(
                                      "Lexend",
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check,
                                      color: Theme.of(context).primaryColor),
                                SizedBox(width: 15),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: StadiumBorder(),
                        backgroundColor: isHelping ? Colors.blue : Colors.red,
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: Text(
                        'Submit',
                        style: GoogleFonts.getFont(
                          "Lexend",
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: isAnyOptionSelected()
                          ? () async {
                              List<String> selectedHelp = helpOptions.entries
                                  .where((entry) => entry.value)
                                  .map((entry) => entry.key)
                                  .toList();
                              print('Phone Number: $phoneNumber');
                              print('Selected Help Options: $selectedHelp');
                              makePostRequest(selectedHelp, isHelping,
                                  currentLat, currentLng);
                              Navigator.pop(context);
                              reloadMapMarkers();
                            }
                          : null,
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      try {
        jsCall('setFlutterInteractive', [false]);
      } catch (_) {}
    }
  }

  // <--------------------- UI --------------------->

  String _formatType(String raw) {
    if (raw.isEmpty) return 'Unknown';
    // Split camelCase into words e.g. reliefCamp → Relief Camp
    final spaced = raw.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  IconData _getIconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('hospital') || t.contains('medic'))
      return FontAwesomeIcons.truckMedical;
    if (t.contains('rescue') || t.contains('boat') || t.contains('evac'))
      return FontAwesomeIcons.lifeRing;
    if (t.contains('water'))
      return FontAwesomeIcons.faucetDrip;
    if (t.contains('power') || t.contains('charg') || t.contains('bolt'))
      return FontAwesomeIcons.bolt;
    if (t.contains('relief') || t.contains('camp'))
      return FontAwesomeIcons.tent;
    if (t.contains('safe') || t.contains('space') || t.contains('shelter'))
      return FontAwesomeIcons.home;
    if (t.contains('supplies') || t.contains('food'))
      return FontAwesomeIcons.boxOpen;
    return FontAwesomeIcons.handsHelping;
  }

  void _showAssistanceDrawer() async {
    try {
      jsCall('setFlutterInteractive', [true]);
    } catch (_) {}
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext bc) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final items = isHelping ? _giveItems : _needItems;
              return Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 10, spreadRadius: 2)
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Drag handle
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Need Help / Give Help toggle inside drawer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: CupertinoSlidingSegmentedControl<int>(
                          children: {
                            0: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text(
                                'Need Help',
                                style: GoogleFonts.getFont('Lexend',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isHelping
                                        ? Colors.grey
                                        : Colors.redAccent),
                              ),
                            ),
                            1: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text(
                                'Give Help',
                                style: GoogleFonts.getFont('Lexend',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color:
                                        isHelping ? Colors.blue : Colors.grey),
                              ),
                            ),
                          },
                          groupValue: isHelping ? 1 : 0,
                          onValueChanged: (int? value) {
                            setState(() {
                              isHelping = value == 1;
                            });
                            setModalState(() {});
                          },
                          backgroundColor: Color(0xFFEEEEEE),
                          thumbColor: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isHelping
                                ? 'Available Requests'
                                : 'Nearby Assistance',
                            style: GoogleFonts.getFont(
                              'Lexend',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${items.length} locations',
                            style: GoogleFonts.getFont(
                              'Lexend',
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                'No locations found',
                                style: GoogleFonts.getFont('Lexend',
                                    color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final loc =
                                    item['location'] as Map<String, dynamic>?;
                                final double itemLat =
                                    (loc?['lat'] as num?)?.toDouble() ??
                                        currentLat;
                                final double itemLng =
                                    (loc?['lng'] as num?)?.toDouble() ??
                                        currentLng;
                                final dist = Geolocator.distanceBetween(
                                    currentLat, currentLng, itemLat, itemLng);
                                final distStr = dist < 1000
                                    ? '${dist.toStringAsFixed(0)}m'
                                    : '${(dist / 1000).toStringAsFixed(1)}km';
                                final String rawType =
                                    (item['type'] ?? '').toString();
                                final String type = _formatType(rawType);
                                final String typeUpper = rawType.toUpperCase();
                                return ListTile(
                                  tileColor: Color(0xFFF7F8FA),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isHelping
                                              ? Colors.blue
                                              : Colors.redAccent)
                                          .withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getIconForType(typeUpper),
                                      color: isHelping
                                          ? Colors.blue
                                          : Colors.redAccent,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    (item['name'] != null && item['name'].toString().isNotEmpty)
                                        ? item['name'].toString()
                                        : type,
                                    style: GoogleFonts.getFont(
                                      'Lexend',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(Icons.place,
                                          size: 13, color: Colors.grey),
                                      SizedBox(width: 3),
                                      Text(
                                        distStr,
                                        style: GoogleFonts.getFont(
                                          'Lexend',
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(Icons.chevron_right,
                                      color: Colors.grey),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showLocationDetails(context, item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      try {
        jsCall('setFlutterInteractive', [false]);
      } catch (_) {}
    }
  }

  Widget _buildTopFloatingBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      height: 48,
      margin: EdgeInsets.only(top: topPadding > 0 ? topPadding + 6 : 14),
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hamburger menu button pinned to the left
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1)
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.menu, color: Colors.black87, size: 21),
                tooltip: 'Menu',
                onPressed: _showAssistanceDrawer,
              ),
            ),
          ),
          // Need Help / Give Help Toggle Pill perfectly centered
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 1)
                ],
              ),
              child: CupertinoSlidingSegmentedControl<int>(
                children: {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    child: Text(
                      'Need Help',
                      style: GoogleFonts.getFont('Lexend',
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: isHelping ? Colors.grey : Colors.redAccent),
                    ),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    child: Text(
                      'Give Help',
                      style: GoogleFonts.getFont('Lexend',
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: isHelping ? Colors.blue : Colors.grey),
                    ),
                  ),
                },
                groupValue: isHelping ? 1 : 0,
                onValueChanged: (int? value) {
                  setState(() {
                    isHelping = value == 1;
                    selectedFilter = '';
                  });
                },
                backgroundColor: Color(0xFFEEEEEE),
                thumbColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineWidget() {
    return Container(
      margin: EdgeInsets.all(20.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white),
          SizedBox(width: 10.0),
          Expanded(
            child: Text(
              'No network connection, switching to SMS mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    List<Map<String, dynamic>> currentFilters =
        isHelping ? filtersGiveHelp : filtersNeedHelp;
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: currentFilters.length,
        itemBuilder: (BuildContext context, int index) {
          Map<String, dynamic> filter = currentFilters[index];
          bool isSelected = filter['type'] == selectedFilter;

          return Container(
            margin: EdgeInsets.symmetric(horizontal: 3),
            child: FilterChip(
              avatar: Icon(filter['icon'],
                  color: isSelected ? Colors.white : Colors.grey),
              label: Text(filter['type'],
                  style: GoogleFonts.getFont('Lexend',
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: isSelected ? Colors.white : Colors.grey)),
              selected: isSelected,
              onSelected: (bool value) {
                setState(() {
                  selectedFilter = value ? filter['type'] : '';
                });
              },
              backgroundColor: Color.fromARGB(255, 227, 227, 227),
              selectedColor: isHelping
                  ? Color.fromARGB(255, 137, 202, 255)
                  : Color.fromARGB(255, 250, 121, 121),
              checkmarkColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.transparent,
                ),
              ),
              shadowColor: Colors.black,
              elevation: 3,
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget recenterBtn() {
    return Positioned(
      right: 16.0,
      bottom: 110.0,
      child: FloatingActionButton(
        mini: false,
        child: Icon(FontAwesomeIcons.streetView, color: Colors.black),
        backgroundColor: Colors.white,
        onPressed: () {
          jsCall('updateWindyLocation', [currentLat, currentLng]);
          _loadJsonData();
        },
      ),
    );
  }

  Widget actionBtn(isHelping, selectedFilter) {
    return Positioned(
      right: 16.0,
      bottom: 45.0,
      child: buildFloatingActionButton(
        isHelping: isHelping,
        selectedFilter: selectedFilter,
      ),
    );
  }

  Widget buildFloatingActionButton({
    required bool isHelping,
    required String selectedFilter,
  }) {
    return FloatingActionButton(
      child: Icon(
        isHelping
            ? FontAwesomeIcons.handHoldingHeart
            : FontAwesomeIcons.handsHelping,
        color: Colors.white,
      ),
      backgroundColor: isHelping
          ? Color.fromARGB(255, 137, 202, 255)
          : Color.fromARGB(255, 250, 121, 121),
      onPressed: actionButtonClickFn,
    );
  }

  Widget _buildItemsPanel() {
    final items = _getFilteredItems();
    if (items.isEmpty) return SizedBox.shrink();
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 10),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final loc2 = item['location'] as Map<String, dynamic>?;
            final double itemLat =
                (loc2?['lat'] as num?)?.toDouble() ?? currentLat;
            final double itemLng =
                (loc2?['lng'] as num?)?.toDouble() ?? currentLng;
            final dist = Geolocator.distanceBetween(
                currentLat, currentLng, itemLat, itemLng);
            final distStr = dist < 1000
                ? '${dist.toStringAsFixed(0)}m'
                : '${(dist / 1000).toStringAsFixed(1)}km';
            return GestureDetector(
              onTap: () => _showLocationDetails(context, item),
              child: Container(
                width: 140,
                margin: EdgeInsets.symmetric(horizontal: 5),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.93),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (item['type'] ?? '').toString().toUpperCase(),
                      style: GoogleFonts.getFont('Lexend',
                          fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.place, size: 12, color: Colors.grey),
                      SizedBox(width: 2),
                      Text(distStr,
                          style: GoogleFonts.getFont('Lexend',
                              fontSize: 11, color: Colors.grey)),
                    ]),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // <--------------------- Build --------------------->
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Map is in HTML background (index.html) — Flutter is fully transparent here
          const SizedBox.expand(),
          Column(
            children: [
              _buildTopFloatingBar(),
              isOffline ? _buildOfflineWidget() : Container(),
            ],
          ),
          recenterBtn(),
          actionBtn(isHelping, selectedFilter),
          SOSButton(
            isHelping: isHelping == true,
            currentLat: currentLat,
            currentLng: currentLng,
          ),
        ],
      ),
    );
  }
}
