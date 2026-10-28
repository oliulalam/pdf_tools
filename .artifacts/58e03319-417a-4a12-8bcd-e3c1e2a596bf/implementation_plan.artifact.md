# Implementation Plan - Split Document Output Wording

When "Split into parts" is selected, the app generates multiple files. However, the export button text is hardcoded to "Export Document" (singular) and the preview section says "1 file". We need to dynamically update this UI to reflect the actual number of files generated.

## Proposed Changes

### [MODIFY] [pdf_splitter_screen.dart](file:///E:/Pdf%20Toold%20App%20Using%20Provider/pdf_toolkit/lib/screen/pdf_splitter_screen/pdf_splitter_screen.dart)

- **Preview Section Title**: Change `"Your new PDF"` to dynamically show `"Your new PDF"` or `"Your new PDFs"` depending on `provider.generatedFiles.length`.
- **Trailing Text**: Change `"1 file"` to `"${provider.generatedFiles.length} files"`.
- **Badge Text**: Change `"1 PDF"` to `"${provider.generatedFiles.length} PDFs"`.
- **Export Button Text**: Change `"Export Document"` to dynamically say `"Export Document"` (if 1) or `"Export ${provider.generatedFiles.length} files to folder"` (if > 1).

This ensures the user is perfectly clear on what will happen when they click the export button.
