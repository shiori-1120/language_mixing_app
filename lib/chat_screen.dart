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
    final previousAiMessage =
        state.isNotEmpty && !state.last.isUser ? state.last.text : "";

    state = [...state, ChatMessage(text: userMessage, isUser: true)];

    try {
      final prompt = _preparePrompt(previousAiMessage, userMessage);
      final response = await _model.generateContent([Content.text(prompt)]);

      final aiResponse = response.text ?? '';
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

String _preparePrompt(String previousAiMessage, String userMessage) {
  return '''
あなたは日本語と英語を自然にミックスして話す言語学習支援AIアシスタントです。

以下のフォーマットを参考に、自然でカジュアルな返答を生成してください。

【フォーマット例1】
「今日は weather がめっちゃ nice だから、ちょっとお気に入りの coffee shop で chill out したい気分だな。」

【フォーマット例2】
「それってほんとに awesome news だね！次の brand new challenge もきっと exciting でめちゃめちゃ fun だと思うよ！」

【フォーマット例3】
「新しい job を start するのって、honestly speaking nervous な感じだけど、それ以上に exciting でワクワクするよね！」

※注意点：
・文中の英語の割合は40％程度にしてください（日本語をベースにして、自然な感じで英語を混ぜてください）。
・英単語を連続して4つ以上使わないでください（冠詞 a や the はカウントしません）。
・英単語を3つ連続して使う部分を文中に必ず1つ入れてください。
・完全に英語だけ、または完全に日本語だけの文は禁止です。
・必ずフレンドリーで明るい口調でお願いします。

前回のあなたのメッセージ：
$previousAiMessage

今回のユーザーメッセージ：
$userMessage

以上を参考にして、自然な会話を作ってください。
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
      appBar: AppBar(title: Text('いい感じのノレー太柴'), centerTitle: true),
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
          children:
              words.map((word) {
                return GestureDetector(
                  onTap: () async {
                    final translatedWord = await _translateWord(
                      word,
                      message.text,
                    );
                    if (translatedWord != null) {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
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
                  child: Text(word, style: TextStyle(fontSize: 16)),
                );
              }).toList(),
        ),
      ),
    );
  }

  final Map<String, String> _cache = {};

  Future<String?> _translateWord(String word, String fullSentence) async {
    final cacheKey = '$word|$fullSentence';
    final model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: dotenv.get('GEMINI_API_KEY'),
    );
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    final prompt = '''
あなたは優秀な翻訳AIアシスタントです。
次の文章の中の『$word』という単語またはフレーズについて、文章全体（$fullSentence）における意味を考慮しながら、日本語の辞書風の説明を提供してください。また、活用されているものは原型の意味も説明してください。
以下のフォーマットに従ってください。

【文章中の意味】
・（簡潔に、文脈を考慮した意味を説明）

【辞書的な意味】
1. （第一の意味、簡潔に日本語で説明）
2. （第二の意味があれば簡潔に）


文章：
$fullSentence
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final translation = response.text?.trim();

    if (translation != null) {
      _cache[cacheKey] = translation;
    }

    return translation;
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
