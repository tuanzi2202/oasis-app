import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

// ✨✨✨ 替换为你的域名 ✨✨✨
const String API_BASE_URL = "https://abc1206.vercel.app/api/mobile"; 

void main() {
  runApp(const OasisApp());
}

class OasisApp extends StatelessWidget {
  const OasisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oasis',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        primaryColor: const Color(0xFF0EA5E9),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFF6366F1),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 数据缓存
  List<dynamic> _links = [];
  List<dynamic> _categories = [];
  List<dynamic> _notes = [];
  String _announcement = "加载中...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ✨ 现在有 4 个 Tab 了 (导航, 便签, 博客, 用户)
    _tabController = TabController(length: 4, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // 禁止左右滑动切换，防止手势冲突
              children: [
                LinksPage(links: _links, categories: _categories, announcement: _announcement),
                NotesPage(notes: _notes),
                const BlogListPage(), // ✨ 新增：博客页
                const UserPage(),     // ✨ 新增：用户页
              ],
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10)),
          color: Color(0xFF0F172A),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.transparent,
          labelColor: const Color(0xFF0EA5E9),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: "导航"),
            Tab(icon: Icon(Icons.sticky_note_2_rounded), text: "便签"),
            Tab(icon: Icon(Icons.article_rounded), text: "博客"), // ✨ 新增图标
            Tab(icon: Icon(Icons.person_rounded), text: "我的"),  // ✨ 新增图标
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        onPressed: () {
            // 点击右下角悬浮按钮打开 AI 对话 (原 Haru 页面)
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatPageWrapper()));
        },
      ),
    );
  }
}

// --- 1. 导航页面 (保持不变) ---
class LinksPage extends StatelessWidget {
  final List links;
  final List categories;
  final String announcement;
  const LinksPage({super.key, required this.links, required this.categories, required this.announcement});

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
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Oasis Mobile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(announcement, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(link['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(link['description'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      onTap: () => launchUrl(Uri.parse(link['url'])),
                    ),
                  );
                },
                childCount: links.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. 便利贴页面 (保持不变) ---
class NotesPage extends StatelessWidget {
  final List notes;
  const NotesPage({super.key, required this.notes});
  
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        padding: const EdgeInsets.all(16),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _parseColor(note['color']),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
            ),
            child: Text(note['content'], style: TextStyle(color: Colors.brown.shade900, fontSize: 14)),
          );
        },
      ),
    );
  }
}

// --- 3. ✨✨✨ 博客列表页 ✨✨✨
class BlogListPage extends StatefulWidget {
  const BlogListPage({super.key});
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
      appBar: AppBar(
        title: const Text("Blog Hub"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final post = _posts[index];
              final date = DateTime.parse(post['createdAt']);
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => BlogDetailPage(postId: post['id'])
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
                      Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 12),
                      Text(post['summary'] ?? '暂无简介', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, height: 1.5)),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

// --- 4. ✨✨✨ 博客详情页 (Markdown) ✨✨✨
class BlogDetailPage extends StatelessWidget {
  final int postId;
  const BlogDetailPage({super.key, required this.postId});

  Future<Map> _fetchDetail() async {
    final res = await http.get(Uri.parse('$API_BASE_URL/blog?id=$postId'));
    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return json['data'];
    }
    throw Exception("Failed");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A)),
      body: FutureBuilder<Map>(
        future: _fetchDetail(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final post = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(post['createdAt'])), style: const TextStyle(color: Colors.white38)),
                const Divider(color: Colors.white10, height: 40),
                MarkdownBody(
                  data: post['content'],
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
                    h1: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    h2: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    code: const TextStyle(backgroundColor: Color(0xFF334155), color: Colors.orangeAccent),
                    blockquote: const TextStyle(color: Colors.grey),
                    blockquoteDecoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- 5. ✨✨✨ 用户页 (登录与管理) ✨✨✨
class UserPage extends StatefulWidget {
  const UserPage({super.key});
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
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isAdmin') ?? false;
    });
  }

  Future<void> _login() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _loading = true);

    try {
      final res = await http.post(
        Uri.parse('$API_BASE_URL/auth'), // 调用刚才写的 Next.js 接口
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameCtrl.text,
          'password': _passwordCtrl.text
        })
      );

      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAdmin', true);
        setState(() => _isLoggedIn = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("欢迎回来，管理员！")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("登录失败：账号或密码错误")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("网络错误: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAdmin');
    setState(() => _isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 80, color: Color(0xFF0EA5E9)),
              const SizedBox(height: 20),
              const Text("管理员已登录", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              const Text("手机端管理功能开发中...", style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 40),
              // 这里未来可以加：添加便签、删除文章等按钮
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text("退出登录"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: _logout,
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Login", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text("请登录以管理内容", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 40),
            TextField(
              controller: _usernameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "账号",
                labelStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.person, color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "密码",
                labelStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.lock, color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                onPressed: _loading ? null : _login,
                child: _loading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Text("立即登录", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- 6. 独立的 AI 对话页 (ChatPageWrapper) ---
// 因为 AI 对话不再放在 Tab 里，而是做成一个独立的页面，方便在任何地方唤起
// 这里复用你之前写的 ChatPage 代码，只需把它包裹在 Scaffold 里即可
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