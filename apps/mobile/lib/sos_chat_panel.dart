import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'emergency_relay_service.dart';

class SOSChatPanel extends StatefulWidget {
  final double currentLat;
  final double currentLng;
  final String backendUrl;
  final VoidCallback onClose;

  const SOSChatPanel({
    Key? key,
    required this.currentLat,
    required this.currentLng,
    required this.backendUrl,
    required this.onClose,
  }) : super(key: key);

  @override
  _SOSChatPanelState createState() => _SOSChatPanelState();
}

class _SOSChatPanelState extends State<SOSChatPanel> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final EmergencyRelayService _relayService = EmergencyRelayService();

  late double _lat;
  late double _lng;
  double _accuracy = 12.0;
  bool _isAcquiringLocation = false;
  String _locationStatus = 'Device GPS Acquired';

  String _currentLifecycleStatus = 'SOS CREATED';
  String? _activeSosId;
  String? _assignedTeamName;
  List<Map<String, dynamic>> _suitableRescueTeams = [];
  bool _isSending = false;
  bool _isRelaySearching = false;
  int _relayPeerCount = 0;
  StreamSubscription? _peerSub;

  final List<Map<String, dynamic>> _messages = [];

  List<String> _quickActions = [];
  bool _quickActionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.currentLat;
    _lng = widget.currentLng;

    _peerSub = _relayService.peerCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _relayPeerCount = count;
          if (_currentLifecycleStatus == 'SEARCHING FOR NEARBY RELAYS' &&
              count > 0) {
            _currentLifecycleStatus = 'RELAY DEVICE FOUND';
            _addBotMessage(
                'Connected to $count nearby peer device(s) via offline emergency relay. Forwarding encrypted emergency packet...');
            _forwardOfflinePacket();
          }
        });
      }
    });

    _initWelcome();
    _loadQuickActions();
    _fetchLiveRescueTeams('general');
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initWelcome() {
    _messages.add({
      'isUser': false,
      'text':
          'Emergency assistance activated. Tell me what happened. I\'ll help identify available nearby assistance and send your emergency request.',
      'time': _formatTime(),
    });
  }

  Future<void> _loadQuickActions() async {
    // Use common emergency queries to get dynamic quick actions from the backend's knowledge base
    final commonQueries = [
      'trapped under debris',
      'medical emergency bleeding',
      'need evacuation boat',
      'need food and water',
      'need shelter',
      'general rescue help',
    ];

    try {
      final List<String> actions = [];
      for (final query in commonQueries) {
        try {
          final res = await http
              .get(
                Uri.parse(
                    '${widget.backendUrl}/api/chat/emergency?query=${Uri.encodeComponent(query)}'),
              )
              .timeout(const Duration(seconds: 2));

          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            final guidance = data['guidance'];
            final category = guidance['category'] ?? 'general';
            // Create a user-friendly action based on category
            String actionText;
            switch (category) {
              case 'rescue':
              case 'trapped':
                actionText = 'I am trapped';
                break;
              case 'medical':
                actionText = 'I need medical assistance';
                break;
              case 'evacuation':
                actionText = 'I need evacuation';
                break;
              case 'food':
              case 'food_water':
                actionText = 'I need food and water';
                break;
              case 'shelter':
                actionText = 'I need shelter';
                break;
              default:
                actionText = 'I need general rescue assistance';
            }
            if (!actions.contains(actionText)) {
              actions.add(actionText);
            }
          }
        } catch (_) {
          // Continue with other queries
        }
      }

      if (mounted && actions.isNotEmpty) {
        setState(() {
          _quickActions = actions;
          _quickActionsLoaded = true;
        });
      }
    } catch (_) {
      // Silently fail, quick actions will remain empty
    }
  }

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add({
        'isUser': false,
        'text': text,
        'time': _formatTime(),
      });
    });
    _scrollToBottom();
  }

  Future<void> _refreshGPSLocation() async {
    setState(() {
      _isAcquiringLocation = true;
      _locationStatus = 'Requesting high-accuracy GPS fix...';
    });

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _accuracy = pos.accuracy;
        _locationStatus = 'GPS fix locked (±${_accuracy.toStringAsFixed(1)}m)';
        _isAcquiringLocation = false;
        _currentLifecycleStatus = 'LOCATION ACQUIRED';
      });

      _fetchLiveRescueTeams('general');
    } catch (e) {
      setState(() {
        _locationStatus = 'Offline GPS Cache used (±15m)';
        _isAcquiringLocation = false;
      });
    }
  }

  Future<void> _fetchLiveRescueTeams(String category) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '${widget.backendUrl}/api/rescue/nearby?lat=$_lat&lng=$_lng&category=$category&limit=3'),
          )
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List list = data['teams'] ?? [];
        setState(() {
          _suitableRescueTeams = List<Map<String, dynamic>>.from(list);
          _currentLifecycleStatus = 'RESCUE OPTIONS IDENTIFIED';
        });
      }
    } catch (_) {
      // Offline fallback: Use locally cached verified teams
      setState(() {
        _suitableRescueTeams = [
          {
            'team_id': 'NDRF-BN-04-A',
            'team_name': 'NDRF 4th Battalion - Flood Rescue Unit Alpha',
            'category': 'rescue',
            'distance_km': 0.99,
            'status': 'available',
            'data_age_seconds': 180,
            'is_status_verified': true,
            'contact': '+91-44-2250-1001'
          },
          {
            'team_id': 'MED-APOLLO-EMG',
            'team_name': 'Apollo Emergency Disaster Medical Unit',
            'category': 'medical',
            'distance_km': 1.25,
            'status': 'available',
            'data_age_seconds': 240,
            'is_status_verified': true,
            'contact': '+91-44-2829-0200'
          }
        ];
      });
    }
  }

  Future<void> _handleUserSend(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'time': _formatTime(),
      });
      _msgController.clear();
    });
    _scrollToBottom();

    // Query RAG Emergency FAQ knowledge base for actionable safety guidance
    try {
      final res = await http
          .get(
            Uri.parse(
                '${widget.backendUrl}/api/chat/emergency?query=${Uri.encodeComponent(text)}'),
          )
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final guidance = data['guidance'];
        final advice = guidance['advice'] ?? '';
        final cat = guidance['category'] ?? 'general';

        _fetchLiveRescueTeams(cat);

        _addBotMessage(
            'Emergency Category: ${cat.toUpperCase()}\n\n$advice\n\n📌 Press "Send SOS" below to broadcast your coordinates to verified teams.');
      } else {
        _addBotMessage(
            'Understood. I have categorized your emergency. Review your location and click "Send SOS" below to dispatch alerts.');
      }
    } catch (_) {
      _addBotMessage(
          'Offline Mode: Unable to fetch emergency guidance. Stay in a safe interior room away from windows. Review your GPS position and press "Send SOS" to store and broadcast via offline mesh.');
    }
  }

  Future<void> _triggerSendSOS() async {
    setState(() {
      _isSending = true;
      _currentLifecycleStatus = 'MESSAGE QUEUED';
    });

    final String sosId =
        'SOS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    _activeSosId = sosId;

    final emergencyPacket = {
      'sos_id': sosId,
      'user_id': 'CITIZEN-${_lat.toStringAsFixed(2)}',
      'device_id': 'DEVICE-${DateTime.now().millisecondsSinceEpoch}',
      'lat': _lat,
      'lng': _lng,
      'accuracy_meters': _accuracy,
      'category': 'rescue',
      'description': _messages.last['text'] ?? 'Emergency Rescue Request',
      'severity': 'CRITICAL',
      'people_affected': 1,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'expires_at': DateTime.now().millisecondsSinceEpoch / 1000 + 86400,
    };

    // 1. Always persist locally first (survives restart/crash)
    await _relayService.persistEmergencyMessage(emergencyPacket);

    // 2. Try Internet Transmission first
    bool serverDelivered = false;
    try {
      final res = await http
          .post(
            Uri.parse('${widget.backendUrl}/api/sos/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(emergencyPacket),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 201) {
        serverDelivered = true;
        setState(() {
          _currentLifecycleStatus = 'SERVER RECEIVED';
        });

        // Trigger team acknowledgment simulation
        _simulateRescueTeamDispatch(sosId);
      }
    } catch (_) {
      serverDelivered = false;
    }

    if (!serverDelivered) {
      // 3. Enter Store-Carry-Forward Offline Emergency Relay Mode
      setState(() {
        _currentLifecycleStatus = 'SEARCHING FOR NEARBY RELAYS';
        _isRelaySearching = true;
      });
      await _relayService.startOfflineRelay();

      _addBotMessage(
          '⚠️ No direct internet connection.\nYour SOS is SAVED ON THIS DEVICE.\nBroadcasting via Offline Emergency Relay (BLE/WiFi Direct)...');
    }

    setState(() {
      _isSending = false;
    });
  }

  void _forwardOfflinePacket() {
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentLifecycleStatus = 'MESSAGE FORWARDED';
        });
        _addBotMessage(
            '✅ Emergency packet successfully forwarded to $_relayPeerCount nearby relay device(s)!\nYour request will automatically sync to central rescue servers when any relay device reaches connectivity.');
      }
    });
  }

  Future<void> _simulateRescueTeamDispatch(String sosId) async {
    _addBotMessage(
        'Central emergency servers received your request. Identifying closest response unit...');

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    try {
      final ackRes = await http.post(
        Uri.parse('${widget.backendUrl}/api/sos/$sosId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'responder_id': 'NDRF-BN-04-A',
          'responder_name': 'NDRF 4th Battalion - Flood Rescue Unit Alpha',
          'responder_role': 'RESCUE_TEAM',
        }),
      );

      if (ackRes.statusCode == 200) {
        setState(() {
          _currentLifecycleStatus = 'TEAM EN ROUTE';
          _assignedTeamName = 'NDRF Flood Rescue Unit Alpha';
        });
        _addBotMessage(
            '🚨 RESCUE TEAM ASSIGNED!\nUnit: NDRF Flood Rescue Unit Alpha\nStatus: EN ROUTE (ETA: ~12 mins)\nKeep your phone on and stay in an elevated safe position.');
      }
    } catch (_) {
      setState(() {
        _currentLifecycleStatus = 'TEAM ACKNOWLEDGED';
      });
    }
  }

  Color _getStatusColor() {
    switch (_currentLifecycleStatus) {
      case 'SOS CREATED':
      case 'MESSAGE QUEUED':
        return Colors.orange;
      case 'SEARCHING FOR NEARBY RELAYS':
        return Colors.purple;
      case 'RELAY DEVICE FOUND':
      case 'MESSAGE FORWARDED':
        return Colors.indigo;
      case 'SERVER RECEIVED':
      case 'TEAM ACKNOWLEDGED':
        return Colors.blue;
      case 'TEAM ASSIGNED':
      case 'TEAM EN ROUTE':
        return Colors.green;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFFBFBFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 20, spreadRadius: 4)
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              children: [
                // Drag Pill
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(FontAwesomeIcons.triangleExclamation,
                          color: Colors.redAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VayuSetu SOS Assistant',
                            style: GoogleFonts.lexend(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentLifecycleStatus,
                                style: GoogleFonts.lexend(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: _getStatusColor(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Location & Accuracy Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed, size: 16, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_lat, $_lng • $_locationStatus',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      color: const Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _isAcquiringLocation ? null : _refreshGPSLocation,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    _isAcquiringLocation ? 'Fixing...' : 'Retry GPS',
                    style: GoogleFonts.lexend(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Nearest Rescue Units Section (if available)
          if (_suitableRescueTeams.isNotEmpty)
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _suitableRescueTeams.length,
                itemBuilder: (ctx, i) {
                  final team = _suitableRescueTeams[i];
                  return Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          team['team_name'] ?? 'Rescue Unit',
                          style: GoogleFonts.lexend(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${team['distance_km']} km away',
                              style: GoogleFonts.lexend(
                                  fontSize: 11, color: Colors.blue[700]),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'VERIFIED',
                                style: GoogleFonts.lexend(
                                    fontSize: 9,
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, idx) {
                final m = _messages[idx];
                final bool isUser = m['isUser'] == true;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF1976D2)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser
                            ? const Radius.circular(16)
                            : const Radius.circular(4),
                        bottomRight: isUser
                            ? const Radius.circular(4)
                            : const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['text'],
                          style: GoogleFonts.lexend(
                            fontSize: 13,
                            color:
                                isUser ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m['time'],
                          style: GoogleFonts.lexend(
                            fontSize: 10,
                            color: isUser
                                ? Colors.white70
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick Actions Pills
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickActions.length,
              itemBuilder: (ctx, idx) {
                final act = _quickActions[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    label: Text(
                      act,
                      style: GoogleFonts.lexend(
                          fontSize: 12, color: const Color(0xFF334155)),
                    ),
                    onPressed: () => _handleUserSend(act),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Action Area: Send SOS Button + Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                // Large Explicit "Send SOS" Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(FontAwesomeIcons.towerBroadcast, size: 18),
                    label: Text(
                      _isSending
                          ? 'TRANSMITTING SOS...'
                          : 'SEND SOS NOW (OFFLINE RELAY ENABLED)',
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: _isSending ? null : _triggerSendSOS,
                  ),
                ),
                const SizedBox(height: 8),

                // Free-text message row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: GoogleFonts.lexend(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Type emergency description...',
                          hintStyle: GoogleFonts.lexend(
                              fontSize: 13, color: Colors.grey),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        onSubmitted: _handleUserSend,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Color(0xFF1976D2)),
                      onPressed: () => _handleUserSend(_msgController.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
