import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import '../core/translations.dart';
import '../core/globals.dart'; 
import '../widgets/agro_pulse_loader.dart';
import '../widgets/fade_in_slide.dart';
import 'gov_schemes_screen.dart'; 

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80, 
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0, left: 8.0),
          child: Row(
            children: [
              Text(
                "Community ", 
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5)
              ),
              Text(
                "Hub", 
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.blueAccent.shade400, letterSpacing: -0.5)
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: isDark ? Colors.blueAccent.shade400 : const Color(0xFF064E3B),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.forum_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text("Forum".tr),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text("Logistics".tr),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text("Schemes".tr),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const ForumTabView(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.local_shipping_outlined, size: 64, color: Colors.blueAccent.shade400),
                ),
                const SizedBox(height: 24),
                Text("Logistics Network", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                const SizedBox(height: 8),
                Text("Connect with transporters.\nComing Soon.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const GovSchemesScreenTab(),
        ],
      ),
    );
  }
}

// ==========================================
// FORUM TAB VIEW
// ==========================================
class ForumTabView extends StatefulWidget {
  const ForumTabView({super.key});

  @override
  State<ForumTabView> createState() => _ForumTabViewState();
}

class _ForumTabViewState extends State<ForumTabView> {
  List<dynamic> posts = [];
  bool isLoading = true;
  int _currentSubTab = 0; 

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  String _formatDateTime(String isoString) {
    try {
      // Force Flutter to treat the incoming DB time as UTC if it lacks a timezone marker
      if (!isoString.endsWith('Z') && !isoString.contains('+') && !isoString.contains('-')) {
        isoString += 'Z';
      }
      
      // Convert the UTC time to the user's local device time
      final DateTime dt = DateTime.parse(isoString).toLocal();
      
      final String date = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      String amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final String time = "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm";
      
      return "$date • $time";
    } catch (e) {
      return isoString.split('T').first; 
    }
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    
    String endpoint = '/community/posts'; 
    if (_currentSubTab == 1) endpoint = '/community/my_posts';
    if (_currentSubTab == 2) endpoint = '/community/my_replies';

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: {"Authorization": "Bearer $token"}
      );
      if (response.statusCode == 200) {
        setState(() => posts = json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching posts: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitPost(String title, String content, {int? editPostId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    try {
      final url = editPostId == null ? '${AppConfig.baseUrl}/community/posts' : '${AppConfig.baseUrl}/community/posts/$editPostId';
      final response = editPostId == null 
          ? await http.post(Uri.parse(url), headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"}, body: json.encode({"title": title, "content": content}))
          : await http.put(Uri.parse(url), headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"}, body: json.encode({"title": title, "content": content}));

      if (response.statusCode == 200) _fetchData();
    } catch (e) {
      debugPrint("Post failed: $e");
    }
  }

  Future<void> _deletePost(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    try {
      final response = await http.delete(Uri.parse('${AppConfig.baseUrl}/community/posts/$postId'), headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) _fetchData();
    } catch (e) {
      debugPrint("Delete failed: $e");
    }
  }

  void _showCreateOrEditPostDialog({Map<String, dynamic>? existingPost}) {
    final bool isEdit = existingPost != null;
    final TextEditingController titleController = TextEditingController(text: isEdit ? existingPost['title'] : "");
    final TextEditingController contentController = TextEditingController(text: isEdit ? existingPost['content'] : "");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEdit ? "Edit Post".tr : "Ask the Community".tr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: "Title (e.g., How to cure leaf curl?)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: InputDecoration(labelText: "Describe your doubt in detail...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueAccent.shade400 : const Color(0xFF064E3B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                      Navigator.pop(context);
                      await _submitPost(titleController.text, contentController.text, editPostId: isEdit ? existingPost['id'] : null);
                    }
                  },
                  child: Text(isEdit ? "Save Changes" : "Post Publicly", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _openPostDetail(Map<String, dynamic> post) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: post, refreshParent: _fetchData)));
  }

  // --- UI RENDERER: Standard Post Card (For Explore & My Posts) ---
  Widget _buildStandardPostCard(Map<String, dynamic> post, int index, bool isDark, bool isMyPost) {
    return FadeInSlide(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openPostDetail(post),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isMyPost 
                              ? (isDark ? Colors.blueAccent.shade700 : Colors.blue.shade100) 
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                          child: Text(
                            post['author_name'][0], 
                            style: TextStyle(fontWeight: FontWeight.w900, color: isMyPost ? Colors.blueAccent.shade400 : (isDark ? Colors.white : Colors.black87), fontSize: 14)
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isMyPost ? "You" : post['author_name'], 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isMyPost ? Colors.blueAccent.shade400 : Theme.of(context).textTheme.bodyLarge!.color)
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _formatDateTime(post['created_at']), 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500)
                        ),
                        if (isMyPost) ...[
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                            onSelected: (value) {
                              if (value == 'edit') _showCreateOrEditPostDialog(existingPost: post);
                              else if (value == 'delete') _deletePost(post['id']);
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(value: 'edit', child: Text('Edit Post', style: TextStyle(fontWeight: FontWeight.bold))),
                              const PopupMenuItem<String>(value: 'delete', child: Text('Delete Post', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(post['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.3)),
                const SizedBox(height: 8),
                Text(
                  post['content'],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueAccent.withOpacity(0.1) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.blueAccent.shade400),
                          const SizedBox(width: 6),
                          Text("${post['replies'].length} Replies", style: TextStyle(color: Colors.blueAccent.shade400, fontWeight: FontWeight.w900, fontSize: 12)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text("Read Discussion".tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI RENDERER: Highlighted Reply Card (For My Replies) ---
  Widget _buildMyReplyCard(Map<String, dynamic> post, int index, bool isDark) {
    // Find the user's latest reply within this post
    final myReplies = (post['replies'] as List).where((r) => r['author_name'] == currentUserName.value).toList();
    if (myReplies.isEmpty) return const SizedBox.shrink(); 
    final myReply = myReplies.last;

    return FadeInSlide(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openPostDetail(post),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Context Mini-Header
                Row(
                  children: [
                    Icon(Icons.reply_rounded, color: Colors.grey.shade500, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "You replied to ${post['author_name']}'s post",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                      ),
                    ),
                    Text(
                      _formatDateTime(myReply['created_at']),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400)
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(post['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  child: Divider(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), height: 1),
                ),

                // 2. The User's Actual Reply Highlighted
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isDark ? Colors.blueAccent.shade700 : Colors.blue.shade100,
                      child: Text(currentUserName.value[0], style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.blueAccent.shade700, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        myReply['content'],
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade800, fontSize: 15, height: 1.4),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 18),
                
                // 3. View More Button Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blueAccent.withOpacity(0.1) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("View Full Discussion", style: TextStyle(color: Colors.blueAccent.shade400, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.blueAccent.shade400),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        isLoading 
            ? const Center(child: AgroPulseLoader(message: "Loading discussions..."))
            : posts.isEmpty 
                ? Center(child: Text(_currentSubTab == 0 ? "No discussions yet.".tr : "Nothing found here.".tr, style: const TextStyle(fontWeight: FontWeight.bold)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16).copyWith(bottom: 120), 
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      bool isMyPost = post['author_name'] == currentUserName.value;

                      // Conditionally render layout based on which sub-tab is active
                      if (_currentSubTab == 2) {
                        return _buildMyReplyCard(post, index, isDark);
                      } else {
                        return _buildStandardPostCard(post, index, isDark, isMyPost);
                      }
                    },
                  ),

        // Floating Action Button
        Positioned(
          right: 16,
          bottom: 90,
          child: FloatingActionButton(
            onPressed: () => _showCreateOrEditPostDialog(),
            backgroundColor: isDark ? Colors.blueAccent.shade400 : const Color(0xFF064E3B),
            elevation: 4,
            child: const Icon(Icons.edit_document, color: Colors.white),
          ),
        ),

        // Sub-Navigation Menu
        Positioned(
          left: 20, right: 20, bottom: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSubNavItem("Explore", Icons.explore_rounded, 0, isDark),
                    _buildSubNavItem("My Posts", Icons.post_add_rounded, 1, isDark),
                    _buildSubNavItem("My Replies", Icons.reply_all_rounded, 2, isDark),
                  ],
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSubNavItem(String label, IconData icon, int index, bool isDark) {
    bool isSelected = _currentSubTab == index;
    return GestureDetector(
      onTap: () {
        if (_currentSubTab != index) {
          setState(() { _currentSubTab = index; });
          _fetchData();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.blueAccent.shade400 : const Color(0xFF064E3B)) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade500),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ]
          ],
        ),
      ),
    );
  }
}

// ==========================================
// POST DETAIL SCREEN
// ==========================================
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback refreshParent;

  const PostDetailScreen({super.key, required this.post, required this.refreshParent});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  late Map<String, dynamic> currentPost;

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
  }

  String _formatDateTime(String isoString) {
    try {
      final DateTime dt = DateTime.parse(isoString).toLocal();
      final String date = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      String amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final String time = "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm";
      return "$date • $time";
    } catch (e) {
      return isoString.split('T').first; 
    }
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/community/posts/${currentPost['id']}/replies'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: json.encode({"content": _replyController.text.trim()}),
      );
      if (response.statusCode == 200) {
        final newReply = json.decode(response.body);
        setState(() {
          currentPost['replies'].add(newReply);
          _replyController.clear();
        });
        widget.refreshParent();
      }
    } catch (e) {
      debugPrint("Reply failed: $e");
    }
  }

  Future<void> _deletePost() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    try {
      final response = await http.delete(Uri.parse('${AppConfig.baseUrl}/community/posts/${currentPost['id']}'), headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        widget.refreshParent();
        if (mounted) Navigator.pop(context); 
      }
    } catch (e) {
      debugPrint("Delete failed: $e");
    }
  }

  void _showEditPostDialog() {
    final TextEditingController titleController = TextEditingController(text: currentPost['title']);
    final TextEditingController contentController = TextEditingController(text: currentPost['content']);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Edit Post".tr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: "Title", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: InputDecoration(labelText: "Description", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueAccent.shade400 : const Color(0xFF064E3B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('jwt_token') ?? '';
                      try {
                        final response = await http.put(
                          Uri.parse('${AppConfig.baseUrl}/community/posts/${currentPost['id']}'),
                          headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
                          body: json.encode({"title": titleController.text, "content": contentController.text})
                        );
                        if (response.statusCode == 200) {
                          setState(() {
                            currentPost['title'] = titleController.text;
                            currentPost['content'] = contentController.text;
                          });
                          widget.refreshParent();
                        }
                      } catch (e) {
                         debugPrint("Edit failed");
                      }
                    }
                  },
                  child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final replies = currentPost['replies'] as List<dynamic>;
    bool isMyPost = currentPost['author_name'] == currentUserName.value;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Discussion", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (isMyPost)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') _showEditPostDialog();
                else if (value == 'delete') _deletePost();
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'edit', child: Text('Edit Post', style: TextStyle(fontWeight: FontWeight.bold))),
                const PopupMenuItem<String>(value: 'delete', child: Text('Delete Post', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(currentPost['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.3)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      child: Text(currentPost['author_name'][0], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentPost['author_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(_formatDateTime(currentPost['created_at']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(currentPost['content'], style: TextStyle(fontSize: 16, height: 1.6, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Divider(),
                ),
                Text("Replies (${replies.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                
                ...replies.map((r) {
                  bool isReplyMine = r['author_name'] == currentUserName.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_rounded, size: 14, color: isReplyMine ? Colors.blueAccent.shade400 : Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(isReplyMine ? "You" : r['author_name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isReplyMine ? Colors.blueAccent.shade400 : null)),
                              ],
                            ),
                            Text(_formatDateTime(r['created_at']), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                          ]
                        ),
                        const SizedBox(height: 8),
                        Text(r['content'], style: const TextStyle(height: 1.4)),
                      ],
                    ),
                  );
                }).toList()
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: isMyPost 
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("You cannot reply to your own post.", style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: InputDecoration(
                          hintText: "Add your helpful reply...",
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? Colors.blueAccent.shade400 : const Color(0xFF064E3B),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: _submitReply,
                      ),
                    )
                  ],
                ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// GOV SCHEMES TAB
// ==========================================
class GovSchemesScreenTab extends StatefulWidget {
  const GovSchemesScreenTab({super.key});

  @override
  State<GovSchemesScreenTab> createState() => _GovSchemesScreenTabState();
}

class _GovSchemesScreenTabState extends State<GovSchemesScreenTab> {
  @override
  Widget build(BuildContext context) {
    return const GovSchemesScreen(showAppBar: false);
  }
}