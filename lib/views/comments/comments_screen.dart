// lib/views/comments/comments_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turisur_app/controllers/comments_controller.dart';
import 'package:turisur_app/services/comments_service.dart';

// Pantalla para envio y consulta de comentarios y respuestas administrativas
class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  String _selectedType = CommentsService.commentTypes.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<CommentsController>(context, listen: false).fetchComments();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Valida y envia el comentario a Supabase
  Future<void> _submitComment(CommentsController controller) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await controller.submitComment(
      comment: _commentController.text,
      type: _selectedType,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Comentario enviado con exito.'),
        ),
      );
      _commentController.clear();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(controller.error ?? 'Error al enviar el comentario.'),
        ),
      );
      controller.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comentarios y Respuestas'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(color: Colors.black.withAlpha(153)),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer<CommentsController>(
                builder: (context, controller, child) {
                  return Column(
                    children: [
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nuevo Comentario',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedType,
                                decoration: InputDecoration(
                                  labelText: 'Tipo',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedType = val);
                                  }
                                },
                                items: CommentsService.commentTypes.map((val) =>
                                  DropdownMenuItem(value: val, child: Text(val.toUpperCase()))
                                ).toList(),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _commentController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Comentario',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: CommentsService.validateComment,
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: controller.isSubmitting ? null : () => _submitComment(controller),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: controller.isSubmitting
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : const Text('Enviar', style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => controller.fetchComments(),
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('Actualizar'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.blue.withAlpha(25),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: const BorderSide(color: Colors.blue),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (controller.isLoadingHistory)
                        const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      else if (controller.myComments.isNotEmpty) ...[
                        const Text(
                          'Historial de Respuestas',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: controller.myComments.length,
                          itemBuilder: (context, index) {
                            final item = controller.myComments[index];
                            final respuesta = item['respuesta'];
                            final fecha = item['created_at'] != null
                                ? DateTime.parse(item['created_at']).toLocal().toString().split('.')[0]
                                : '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Badge(
                                          label: Text(item['tipo'].toString().toUpperCase()),
                                          backgroundColor: Colors.blueGrey,
                                        ),
                                        Text(fecha, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text('Tu escribiste:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                    Text(item['comentario'] ?? '', style: const TextStyle(fontSize: 15)),
                                    const Divider(height: 25),
                                    const Text('Respuesta Admin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                                    const SizedBox(height: 6),
                                    if (respuesta != null && respuesta.toString().isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withAlpha(20),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.green.withAlpha(51)),
                                        ),
                                        child: Text(
                                          respuesta.toString(),
                                          style: const TextStyle(color: Colors.black87),
                                        ),
                                      )
                                    else
                                      const Row(
                                        children: [
                                          Icon(Icons.access_time, size: 16, color: Colors.orange),
                                          SizedBox(width: 6),
                                          Text('Pendiente de respuesta', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        const Text(
                          'No hay comentarios registrados.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                      const SizedBox(height: 50),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}