import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

// ✨✨✨ 替换为你的 Vercel 域名 ✨✨✨
const String API_BASE_URL = "https://abc1206.vercel.app/api/mobile";

void main() {
  runApp(const OasisApp());
}

class OasisApp extends StatelessWidget {
  const OasisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oasis Admin',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        primaryColor: const Color(0xFF0EA5E9),
        dialogBackgroundColor: const Color(0xFF1E293B), // 弹窗背景色
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFF6366F1),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- 全局工具类：封装带密码的请求 ---
class AdminApi {
  static Future<String?> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('adminPassword');
  }

  static Future<bool> put(String endpoint, Map data) async {
    final pwd = await getPassword();
    if (pwd == null) return false;
    final res = await http.put(
      Uri.parse('$API_BASE_URL/admin/$endpoint'),
      headers: {'Content-Type': 'application/json', 'x-admin-password': pwd},
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  static Future<bool> post(String endpoint, Map data) async {
    final pwd = await getPassword();
    if (pwd == null) return false;
    final res = await http.post(
      Uri.parse('$API_BASE_URL/admin/$endpoint'),
      headers: {'Content-Type': 'application/json', 'x-admin-password': pwd},
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  static Future<bool> delete(String endpoint, int id) async {
    final pwd = await getPassword();
    if (pwd == null) return false;
    final res = await http.delete(
      Uri.parse('$API_BASE_URL/admin/$endpoint?id=$id'),
      headers: {'x-admin-password': pwd},
    );
    return res.statusCode == 200;
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<dynamic> _links = [];
  List<dynamic> _categories = [];
  List<dynamic> _notes = [];
  String _announcement = "加载中...";
  bool _isLoading = true;
  bool _isAdmin = false; // ✨ 全局管理员状态

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminAndFetchData();
  }

  Future<void> _checkAdminAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('isAdmin') ?? false;
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse('$API_BASE_URL/data'));
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json['success']) {
          setState(() {
            _links = json['data']['links'];
            _categories = json['data']['categories'];
            _announcement = json['data']['announcement'];
            _notes = json['data']['notes'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // 子页面回调：当用户登录成功或数据变更时刷新
  void _refresh() {
    _checkAdminAndFetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                LinksPage(links: _links, categories: _categories, announcement: _announcement, isAdmin: _isAdmin, onRefresh: _fetchData),
                NotesPage(notes: _notes, isAdmin: _isAdmin, onRefresh: _fetchData),
                BlogListPage(isAdmin: _isAdmin),
                UserPage(onLoginSuccess: _refresh, onLogout: _refresh),
              ],
            ),
      bottomNavigationBar: Container(
        color: const Color(0xFF0F172A),
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.transparent,
          labelColor: const Color(0xFF0EA5E9),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: "导航"),
            Tab(icon: Icon(Icons.sticky_note_2_rounded), text: "便签"),
            Tab(icon: Icon(Icons.article_rounded), text: "博客"),
            Tab(icon: Icon(Icons.person_rounded), text: "我的"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatPageWrapper())),
      ),
    );
  }
}

// --- 1. 导航页面 (支持长按编辑) ---
class LinksPage extends StatelessWidget {
  final List links;
  final List categories;
  final String announcement;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const LinksPage({super.key, required this.links, required this.categories, required this.announcement, required this.isAdmin, required this.onRefresh});

  void _showEditDialog(BuildContext context, Map? link) {
    final titleCtrl = TextEditingController(text: link?['title'] ?? '');
    final urlCtrl = TextEditingController(text: link?['url'] ?? '');
    final descCtrl = TextEditingController(text: link?['description'] ?? '');
    // 简单处理：默认用第一个分类或当前分类
    String category = link?['category'] ?? (categories.isNotEmpty ? categories[0]['name'] : 'General');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(link == null ? "新增链接" : "编辑链接"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "标题", filled: true)),
            const SizedBox(height: 10),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "URL", filled: true)),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "描述", filled: true)),
          ],
        ),
        actions: [
          if (link != null)
            TextButton(
              onPressed: () async {
                if (await AdminApi.delete('links', link['id'])) {
                  Navigator.pop(ctx);
                  onRefresh();
                }
              },
              child: const Text("删除", style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () async {
              final data = {
                'title': titleCtrl.text,
                'url': urlCtrl.text,
                'description': descCtrl.text,
                'category': category
              };
              bool success;
              if (link == null) {
                success = await AdminApi.post('links', data);
              } else {
                data['id'] = link['id'];
                success = await AdminApi.put('links', data);
              }
              if (success) {
                Navigator.pop(ctx);
                onRefresh();
              }
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.indigo.shade900, Colors.blue.shade900]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Oasis Mobile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(announcement, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final link = links[index];
                  return GestureDetector(
                    onLongPress: isAdmin ? () => _showEditDialog(context, link) : null, // ✨ 管理员长按编辑
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(link['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(link['description'] ?? '', maxLines: 1),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => launchUrl(Uri.parse(link['url'])),
                      ),
                    ),
                  );
                },
                childCount: links.length,
              ),
            ),
          ),
          // 底部留白给 FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// --- 2. 便签页面 (支持点击编辑) ---
class NotesPage extends StatelessWidget {
  final List notes;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const NotesPage({super.key, required this.notes, required this.isAdmin, required this.onRefresh});

  Color _parseColor(String colorName) {
    switch (colorName) {
      case 'yellow': return const Color(0xFFFEF08A);
      case 'pink': return const Color(0xFFFBCFE8);
      case 'blue': return const Color(0xFFBAE6FD);
      case 'green': return const Color(0xFFA7F3D0);
      case 'purple': return const Color(0xFFE9D5FF);
      default: return const Color(0xFFFEF08A);
    }
  }

  void _showEditDialog(BuildContext context, Map? note) {
    final contentCtrl = TextEditingController(text: note?['content'] ?? '');
    String color = note?['color'] ?? 'yellow';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(note == null ? "写便签" : "编辑便签"),
        content: TextField(
          controller: contentCtrl, 
          maxLines: 5,
          decoration: const InputDecoration(filled: true, hintText: "写点什么..."),
        ),
        actions: [
          if (note != null)
            TextButton(
              onPressed: () async {
                if (await AdminApi.delete('notes', note['id'])) {
                  Navigator.pop(ctx);
                  onRefresh();
                }
              },
              child: const Text("删除", style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () async {
              final data = {'content': contentCtrl.text, 'color': color};
              bool success;
              if (note == null) {
                success = await AdminApi.post('notes', data);
              } else {
                data['id'] = note['id'];
                success = await AdminApi.put('notes', data);
              }
              if (success) {
                Navigator.pop(ctx);
                onRefresh();
              }
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        padding: const EdgeInsets.all(16),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return GestureDetector(
            onTap: isAdmin ? () => _showEditDialog(context, note) : null, // ✨ 管理员点击编辑
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _parseColor(note['color']),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
              ),
              child: Text(note['content'], style: TextStyle(color: Colors.brown.shade900, fontSize: 14)),
            ),
          );
        },
      ),
      floatingActionButton: isAdmin ? FloatingActionButton(
        onPressed: () => _showEditDialog(context, null),
        child: const Icon(Icons.add),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// --- 3. 博客列表 ---
class BlogListPage extends StatefulWidget {
  final bool isAdmin;
  const BlogListPage({super.key, required this.isAdmin});
  @override
  State<BlogListPage> createState() => _BlogListPageState();
}

class _BlogListPageState extends State<BlogListPage> {
  List _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final res = await http.get(Uri.parse('$API_BASE_URL/blog'));
      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _posts = json['data'];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blog Hub"), backgroundColor: Colors.transparent, elevation: 0),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final post = _posts[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => BlogDetailPage(postId: post['id'], isAdmin: widget.isAdmin, onUpdate: _fetchPosts)
                  ));
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(post['summary'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

// --- 4. 博客详情 & 编辑 ---
class BlogDetailPage extends StatefulWidget {
  final int postId;
  final bool isAdmin;
  final VoidCallback onUpdate;
  const BlogDetailPage({super.key, required this.postId, required this.isAdmin, required this.onUpdate});

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  Map? _post;
  bool _editing = false;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final res = await http.get(Uri.parse('$API_BASE_URL/blog?id=${widget.postId}'));
    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      setState(() {
        _post = json['data'];
        _titleCtrl.text = _post!['title'];
        _contentCtrl.text = _post!['content'];
      });
    }
  }

  Future<void> _save() async {
    final success = await AdminApi.put('blog', {
      'id': widget.postId,
      'title': _titleCtrl.text,
      'content': _contentCtrl.text,
      'summary': _contentCtrl.text.length > 50 ? _contentCtrl.text.substring(0, 50) : _contentCtrl.text
    });
    if (success) {
      setState(() => _editing = false);
      _fetchDetail();
      widget.onUpdate();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已保存")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_post == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: Icon(_editing ? Icons.save : Icons.edit),
              onPressed: () {
                if (_editing) _save();
                else setState(() => _editing = true);
              },
            ),
          if (widget.isAdmin && _editing)
             IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () async {
                if (await AdminApi.delete('blog', widget.postId)) {
                  Navigator.pop(context);
                  widget.onUpdate();
                }
              },
            ),
        ],
      ),
      body: _editing 
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(controller: _titleCtrl, style: const TextStyle(fontSize: 20, color: Colors.white), decoration: const InputDecoration(hintText: "标题")),
                const SizedBox(height: 10),
                Expanded(child: TextField(controller: _contentCtrl, maxLines: null, style: const TextStyle(color: Colors.white70), decoration: const InputDecoration(hintText: "内容 (支持 Markdown)", border: InputBorder.none))),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_post!['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const Divider(color: Colors.white10, height: 40),
                MarkdownBody(data: _post!['content'], styleSheet: MarkdownStyleSheet(p: const TextStyle(color: Colors.white70, fontSize: 16))),
              ],
            ),
          ),
    );
  }
}

// --- 5. 用户页 (登录逻辑) ---
class UserPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onLogout;
  const UserPage({super.key, required this.onLoginSuccess, required this.onLogout});
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  bool _isLoggedIn = false;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isLoggedIn = prefs.getBool('isAdmin') ?? false);
  }

  Future<void> _login() async {
    if (_usernameCtrl.text.isEmpty) return;
    setState(() => _loading = true);

    try {
      final res = await http.post(
        Uri.parse('$API_BASE_URL/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _usernameCtrl.text, 'password': _passwordCtrl.text})
      );
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAdmin', true);
        await prefs.setString('adminPassword', _passwordCtrl.text); // ✨ 保存密码用于 API 鉴权
        setState(() => _isLoggedIn = true);
        widget.onLoginSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("登录失败")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user, size: 80, color: Color(0xFF0EA5E9)),
            const SizedBox(height: 20),
            const Text("管理员已登录", style: TextStyle(color: Colors.white)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // 清除所有登录信息
                setState(() => _isLoggedIn = false);
                widget.onLogout();
              },
              child: const Text("退出登录"),
            )
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Login", style: TextStyle(fontSize: 32, color: Colors.white)),
          const SizedBox(height: 40),
          TextField(controller: _usernameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "账号", filled: true)),
          const SizedBox(height: 20),
          TextField(controller: _passwordCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "密码", filled: true)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _loading ? null : _login,
            child: const Text("登录"),
          )
        ],
      ),
    );
  }
}

// --- 6. 独立的 AI 对话页 (ChatPageWrapper) ---
// ✨ 请务必把你之前保存的 ChatPage 代码完整粘贴在这里！
// ✨ 为了代码运行，这里必须要有 ChatPage 类。
class ChatPageWrapper extends StatelessWidget {
  const ChatPageWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Haru AI"), backgroundColor: const Color(0xFF0F172A)),
      body: const ChatPage(), // 👈 调用你之前写好的 ChatPage 组件
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, String>> _messages = [
    {'role': 'assistant', 'content': '嘿！我是 Haru，今天想聊点什么？'}
  ];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isThinking = false;

  // --- 自定义配置状态 ---
  bool _useCustomApi = false;
  String _customApiUrl = "https://api.openai.com/v1/chat/completions";
  String _customApiKey = "";
  String _customModel = "gpt-3.5-turbo";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 加载本地配置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useCustomApi = prefs.getBool('useCustomApi') ?? false;
      _customApiUrl = prefs.getString('customApiUrl') ?? "https://api.openai.com/v1/chat/completions";
      _customApiKey = prefs.getString('customApiKey') ?? "";
      _customModel = prefs.getString('customModel') ?? "gpt-3.5-turbo";
    });
  }

  // 保存配置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCustomApi', _useCustomApi);
    await prefs.setString('customApiUrl', _customApiUrl);
    await prefs.setString('customApiKey', _customApiKey);
    await prefs.setString('customModel', _customModel);
  }

  // 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 发送消息核心逻辑
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isThinking = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      String reply = "";

      if (_useCustomApi && _customApiKey.isNotEmpty) {
        // ✨ 模式 A: 自定义 API
        reply = await _fetchCustomApi(text);
      } else {
        // ✨ 模式 B: 默认服务器
        reply = await _fetchServerApi(text);
      }

      setState(() {
        _messages.add({'role': 'assistant', 'content': reply});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'system', 'content': '连接失败: $e'});
      });
    } finally {
      setState(() => _isThinking = false);
      _scrollToBottom();
    }
  }

  // 调用 Next.js 后端
  Future<String> _fetchServerApi(String text) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': text}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['reply'];
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  // 调用自定义 API (OpenAI 格式)
  Future<String> _fetchCustomApi(String text) async {
    try {
      final response = await http.post(
        Uri.parse(_customApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_customApiKey',
        },
        body: jsonEncode({
          'model': _customModel,
          'messages': [
            // 保持和网页端一致的人设
            {'role': 'system', 'content': '你是一个可爱的看板娘Haru，说话简短有趣，带点傲娇。'},
            ..._messages.map((m) => {'role': m['role'] == 'system' ? 'assistant' : m['role'], 'content': m['content']}).toList().take(10),
            {'role': 'user', 'content': text}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return json['choices'][0]['message']['content'];
      } else {
        throw Exception('API Error: ${response.body}');
      }
    } catch (e) {
      throw Exception('自定义接口请求失败: $e');
    }
  }

  // 弹出设置窗口
  void _showSettingsDialog() {
    final urlCtrl = TextEditingController(text: _customApiUrl);
    final keyCtrl = TextEditingController(text: _customApiKey);
    final modelCtrl = TextEditingController(text: _customModel);
    bool tempUseCustom = _useCustomApi;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Haru 设置", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text("使用自定义 API", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: tempUseCustom,
                  activeColor: const Color(0xFF0EA5E9),
                  onChanged: (val) => setDialogState(() => tempUseCustom = val),
                ),
                if (tempUseCustom) ...[
                  const SizedBox(height: 10),
                  _buildTextField("API 地址 (URL)", urlCtrl, "https://..."),
                  const SizedBox(height: 10),
                  _buildTextField("API Key (sk-...)", keyCtrl, "sk-xxxxxx"),
                  const SizedBox(height: 10),
                  _buildTextField("模型名称 (Model)", modelCtrl, "gpt-3.5-turbo"),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _useCustomApi = tempUseCustom;
                  _customApiUrl = urlCtrl.text.trim();
                  _customApiKey = keyCtrl.text.trim();
                  _customModel = modelCtrl.text.trim();
                });
                _saveSettings(); // 保存到本地
                Navigator.pop(context);
              },
              child: const Text("保存", style: TextStyle(color: Color(0xFF0EA5E9))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 顶部栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
              color: Color(0xFF0F172A),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("与 Haru 对话", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.settings, color: _useCustomApi ? const Color(0xFF0EA5E9) : Colors.white54),
                  onPressed: _showSettingsDialog,
                ),
              ],
            ),
          ),
          
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final isSystem = msg['role'] == 'system';
                
                if (isSystem) {
                  return Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(msg['content']!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))));
                }

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF6366F1) : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? Radius.zero : null,
                        bottomLeft: !isUser ? Radius.zero : null,
                      ),
                    ),
                    child: Text(msg['content']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                );
              },
            ),
          ),
          
          // 输入框
          if (_isThinking) const Padding(padding: EdgeInsets.all(8.0), child: Text("Haru 正在思考...", style: TextStyle(color: Colors.white54, fontSize: 10))),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF1E293B)),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "发送消息...",
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF0EA5E9)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}