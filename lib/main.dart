import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

// ✨ 配置你的电脑 IP 地址 (模拟器无法访问 localhost)
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
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate-900
        cardColor: const Color(0xFF1E293B), // Slate-800
        primaryColor: const Color(0xFF0EA5E9), // Sky-500
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFF6366F1), // Indigo-500
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
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse('$API_BASE_URL/data'));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
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
      debugPrint("Error fetching data: $e");
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
              children: [
                LinksPage(links: _links, categories: _categories, announcement: _announcement),
                NotesPage(notes: _notes),
                const ChatPage(),
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
            Tab(icon: Icon(Icons.chat_bubble_rounded), text: "Haru"),
          ],
        ),
      ),
    );
  }
}

// --- 1. 导航页面 ---
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
          // 头部公告
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
          // 资源列表
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final link = links[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.white10),
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.language, color: Colors.white54),
                      ),
                      title: Text(link['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(link['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                            child: Text(link['category'], style: const TextStyle(fontSize: 10, color: Colors.white60)),
                          )
                        ],
                      ),
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

// --- 2. 便利贴页面 (瀑布流) ---
class NotesPage extends StatelessWidget {
  final List notes;
  const NotesPage({super.key, required this.notes});

  Color _parseColor(String colorName) {
    switch (colorName) {
      case 'yellow': return const Color(0xFFFEF08A); // yellow-200
      case 'pink': return const Color(0xFFFBCFE8); // pink-200
      case 'blue': return const Color(0xFFBAE6FD); // sky-200
      case 'green': return const Color(0xFFA7F3D0); // emerald-200
      case 'purple': return const Color(0xFFE9D5FF); // purple-200
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
          final bgColor = _parseColor(note['color']);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4), // 模仿便利贴的方角
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note['content'],
                  style: TextStyle(color: Colors.brown.shade900, fontSize: 14, height: 1.4, fontFamily: 'monospace'), // 假设手写体
                ),
                const SizedBox(height: 10),
                Text(
                  "#${note['id']}",
                  style: TextStyle(color: Colors.brown.shade900.withOpacity(0.4), fontSize: 10),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- 3. AI 对话页面 ---
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
  bool _isThinking = false;

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isThinking = true;
      _inputController.clear();
    });

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add({'role': 'assistant', 'content': json['reply']});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'system', 'content': '连接失败: $e'});
      });
    } finally {
      setState(() => _isThinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
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
          if (_isThinking) const Padding(padding: EdgeInsets.all(8.0), child: Text("Haru 正在输入...", style: TextStyle(color: Colors.white54, fontSize: 10))),
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