import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Network error occurred']);
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final GenerativeModel _model;

  ChatNotifier()
    : _model = GenerativeModel(
        model: 'gemini-1.5-pro',
        apiKey: dotenv.get('GEMINI_API_KEY'),
      ),
      super([]);

  Future<void> sendMessage(String userMessage) async {
    state = [...state, ChatMessage(text: userMessage, isUser: true)];

    try {
      final prompt = _preparePrompt(userMessage);
      final response = await _model.generateContent([Content.text(prompt)]);

      final aiResponse = _mixLanguages(response.text ?? '');
      state = [...state, ChatMessage(text: aiResponse, isUser: false)];
    } catch (e) {
      String errorMessage;
      if (e is NetworkException) {
        errorMessage = 'ネットワークエラー発生。Try again later, okay?';
      } else if (e is TimeoutException) {
        errorMessage = '接続がタイムアウトしました。Slow internet, maybe?';
      } else {
        errorMessage = '予期せぬエラーが発生。Oops! Something went wrong.';
      }

      state = [...state, ChatMessage(text: errorMessage, isUser: false)];
    }
  }

  String _mixLanguages(String originalResponse) {
    return originalResponse.replaceAllMapped(RegExp(r'\b(\w+)\b'), (match) {
      return _randomlyTranslateWord(match.group(0)!);
    });
  }

  String _randomlyTranslateWord(String word) {
    return word;
  }

  String _preparePrompt(String userMessage) {
    return '''
あなたは日本語と英語を自然にミックスして話す言語学習支援AIアシスタントです。
返信の文章の4割程度の単語を英語に置き換え、日本語と英語を混ぜながら話してください。
英語のみの文章を生成しないでください。
【例】
今日は weather がすごく nice だから、ちょっと walk でもしようかなって思ってるんだよね。でも homework がまだ finish してなくて、honestly 少し stress を感じてる。

日本人の韓国アイドルが韓国語と日本語をごちゃまぜにして話すように英語と日本語をミックスして話してください。
（ハンボノの英語×日本語バージョンのような感じ。）

以下のメッセージに対して、面白く、カジュアルで親しみやすい返答をお願いします：


$userMessage
''';
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((
  ref,
) {
  return ChatNotifier();
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chatMessages = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(title: Text('いい感じのルー大柴'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final message = chatMessages[chatMessages.length - 1 - index];
                return _buildChatBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

Widget _buildChatBubble(ChatMessage message) {
  final words = message.text.split(RegExp(r'\s+'));

  return Align(
    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isUser ? Colors.blue[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 4.0,
        runSpacing: 4.0,
        children: words.map((word) {
          return GestureDetector(
            onTap: () async {
              final translatedWord = await _translateWord(word);
              if (translatedWord != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(word),
                    content: Text(translatedWord),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Text(
              word,
              style: TextStyle(fontSize: 16),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

Future<String?> _translateWord(String word) async {
  // ここで実際に辞書APIを呼び出して単語を翻訳できます。
  // とりあえず仮実装として
  return 'Translation of "$word"';
}

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'メッセージを入力...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final message = _textController.text.trim();
    if (message.isNotEmpty) {
      ref.read(chatProvider.notifier).sendMessage(message);
      _textController.clear();
    }
  }

  
}

