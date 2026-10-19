import 'document_text.dart';
import 'field_definition.dart';

/// Describes a kind of document as a list of fields.
///
/// ```dart
/// const invoice = DocumentSchema(
///   id: 'invoice',
///   name: 'Invoice',
///   fields: [
///     FieldDefinition(
///       key: 'number',
///       label: 'Invoice number',
///       type: FieldType.identifier,
///       locators: [KeywordLocator(['شماره فاکتور'], value: RegExp(r'\d+'))],
///     ),
///   ],
/// );
/// ```
class DocumentSchema {
  /// Creates a schema.
  const DocumentSchema({
    required this.id,
    required this.name,
    required this.fields,
  });

  /// Identifier stored in results.
  final String id;

  /// Human readable name.
  final String name;

  /// Fields of the document.
  final List<FieldDefinition> fields;

  /// Fields to extract from [document].
  ///
  /// Returns [fields] by default. Override it for schemas whose fields depend
  /// on the document, like [KeyValueSchema].
  List<FieldDefinition> fieldsFor(DocumentText document) => fields;
}
