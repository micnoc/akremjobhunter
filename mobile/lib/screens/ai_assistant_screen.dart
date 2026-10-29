import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  String? _attachedFileName;
  String? _attachedFilePath;
  String _selectedDocType = 'contract';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ApiService.getChatMessages();
      if (mounted) {
        setState(() {
          if (history.isNotEmpty) {
            _messages.clear();
            for (var m in history) {
              _messages.add({
                'role': m['role'],
                'content': m['content'],
                'doc_name': m['document_name'],
              });
            }
          } else {
            // Default welcome message
            _messages.add({
              'role': 'assistant',
              'content': '👋 Hello! I am your VisaJob AI Employment & Immigration Assistant.\\n\\n'
                  'I can analyze employment contracts for scams, score your CV for ATS systems, verify job offer letters, and answer visa questions for Canada, Germany, France, or Gulf countries.',
            });
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

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

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _promptController.text.trim();
    if (text.isEmpty && _attachedFilePath == null) return;

    _promptController.clear();
    setState(() {
      _messages.add({
        'role': 'user',
        'content': text.isNotEmpty ? text : 'Uploaded document for analysis: $_attachedFileName',
        'doc_name': _attachedFileName,
      });
      _loading = true;
    });
    _scrollToBottom();

    try {
      String reply = '';
      if (_attachedFilePath != null) {
        final analysis = await ApiService.analyzeDocument(
          _attachedFilePath!,
          _attachedFileName ?? 'document.pdf',
          _selectedDocType,
        );
        final map = analysis['analysis'] as Map<String, dynamic>? ?? {};
        final docName = analysis['document_name'] ?? 'Document';
        final details = map.entries.map((e) => '• **${e.key}:** ${e.value}').join('\n');
        reply = '📋 **$docName Analysis:**\n\n$details';
        _attachedFilePath = null;
        _attachedFileName = null;
      } else {
        reply = await ApiService.sendChatMessage(text);
      }

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': reply,
          });
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '⚠️ Could not process inquiry: $e',
          });
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickDocument() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
    );
    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        _attachedFilePath = files.first.path;
        _attachedFileName = files.first.name;
      });

      // Show document type selection sheet
      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Select Document Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.assignment_outlined, color: AppTheme.primary),
                  title: const Text('Employment Contract (Scam & Terms Review)'),
                  onTap: () {
                    setState(() => _selectedDocType = 'contract');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppTheme.secondary),
                  title: const Text('CV / Resume (ATS Compatibility Scoring)'),
                  onTap: () {
                    setState(() => _selectedDocType = 'cv');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.verified_outlined, color: AppTheme.accent),
                  title: const Text('Job Offer Letter (Authenticity Verification)'),
                  onTap: () {
                    setState(() => _selectedDocType = 'offer');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
        final isRtl = LanguageController.instance.isRtl;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRtl ? 'المساعد الذكي للتوظيف والفيزا' : 'AI Employment & Visa Assistant',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  isRtl ? 'تحليل العقود • مطابقة ATS • استشارات الهجرة' : 'Contract Review • ATS Score • Immigration Q&A',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick Action Chips
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _buildQuickChip(isRtl ? '🇨🇦 كندا: LMIA و Express Entry' : '🇨🇦 Canada LMIA & Express Entry', 'Explain Canada LMIA and Express Entry requirements'),
                const SizedBox(width: 8),
                _buildQuickChip(isRtl ? '🇩🇪 ألمانيا: كارت الفرصة Chancenkarte' : '🇩🇪 Germany Chancenkarte', 'What are the points required for Germany Chancenkarte visa?'),
                const SizedBox(width: 8),
                _buildQuickChip(isRtl ? '🇫🇷 فرنسا: جواز الموهبة Passeport Talent' : '🇫🇷 France Talent Passport', 'Explain France Passeport Talent requirements'),
                const SizedBox(width: 8),
                _buildQuickChip(isRtl ? '📄 كيف أرفع نسبة قبول الـ ATS؟' : '📄 Optimize CV for ATS', 'How to optimize my CV for international ATS filters?'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m['role'] == 'user';
                return _buildMessageBubble(m['content'] ?? '', isUser, m['doc_name']);
              },
            ),
          ),

          if (_loading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('VisaJob AI is analyzing...', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),

          // Attachment Banner
          if (_attachedFileName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primarySoft,
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_attachedFileName ($_selectedDocType)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                    onPressed: () => setState(() {
                      _attachedFilePath = null;
                      _attachedFileName = null;
                    }),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.upload_file_rounded, color: AppTheme.primary),
                  tooltip: 'Upload Contract, CV, or Offer Letter',
                  onPressed: _pickDocument,
                ),
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: isRtl ? 'اسأل المساعد الذكي أو ارفع ملفاً...' : 'Ask AI or upload a document...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String prompt) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.surface,
      side: const BorderSide(color: AppTheme.border),
      onPressed: () => _sendMessage(prompt),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, String? docName) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (docName != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attachment, size: 14, color: isUser ? Colors.white70 : AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    docName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUser ? Colors.white70 : AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : AppTheme.textPrimary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
