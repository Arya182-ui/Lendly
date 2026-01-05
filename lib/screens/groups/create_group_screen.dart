import 'package:flutter/material.dart';
import '../../services/group_service.dart';
import '../../services/session_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
    bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  String groupName = '';
  String groupType = '';
  String description = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1a237e),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFE8F9F1),
                        child: Icon(Icons.groups, color: Color(0xFF1DBF73), size: 38),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Group Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a237e))),
                          const SizedBox(height: 6),
                          TextFormField(
                            maxLength: 30,
                            decoration: InputDecoration(
                              hintText: 'e.g. Hostel 7, Robotics Group',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFB),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter group name';
                              }
                              if (value.trim().length < 3) {
                                return 'Group name must be at least 3 characters';
                              }
                              if (value.trim().length > 30) {
                                return 'Max 30 characters allowed';
                              }
                              return null;
                            },
                            onSaved: (value) => groupName = value ?? '',
                          ),
                          const SizedBox(height: 16),
                          const Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a237e))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              hintText: 'Select group type',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFB),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            value: groupType.isEmpty ? null : groupType,
                            items: const [
                              DropdownMenuItem(value: 'study', child: Text('Study')),
                              DropdownMenuItem(value: 'hobby', child: Text('Hobby')),
                              DropdownMenuItem(value: 'sports', child: Text('Sports')),
                              DropdownMenuItem(value: 'tech', child: Text('Tech')),
                              DropdownMenuItem(value: 'social', child: Text('Social')),
                              DropdownMenuItem(value: 'other', child: Text('Other')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                groupType = value ?? '';
                              });
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Select group type';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a237e))),
                          const SizedBox(height: 6),
                          TextFormField(
                            maxLength: 120,
                            decoration: InputDecoration(
                              hintText: 'What is this group about?',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFB),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a description';
                              }
                              if (value.trim().length < 10) {
                                return 'Description must be at least 10 characters';
                              }
                              if (value.trim().length > 120) {
                                return 'Max 120 characters allowed';
                              }
                              return null;
                            },
                            onSaved: (value) => description = value ?? '',
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  _formKey.currentState!.save();
                                  setState(() => _loading = true);
                                  try {
                                    final uid = await SessionService.getUid();
                                    if (uid == null) {
                                      throw Exception('User not logged in');
                                    }
                                    print('Creating group with: name=$groupName, type=$groupType, description=$description, createdBy=$uid');
                                    final groupService = GroupService();
                                    await groupService.createGroup({
                                      'name': groupName,
                                      'type': groupType,
                                      'description': description,
                                      'createdBy': uid,
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Group created!')),
                                      );
                                      Navigator.pop(context, true); // Return true to indicate refresh needed
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _loading = false);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DBF73),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                elevation: 2,
                              ),
                                child: _loading
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Create Group'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
