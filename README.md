# TextUtil.app

![TextUtil Icon](Icon/TextUtil-macOS-128x128@2x.png)

A native macOS applet for batch conversion of documents between common text formats. Wraps the built-in macOS `textutil` command-line tool in a SwiftUI interface.

Built with **OMC 5.0** engine — [github.com/abra-code/OMC](https://github.com/abra-code/OMC/)  
UI rendered by **ActionUI** — [github.com/abra-code/ActionUI](https://github.com/abra-code/ActionUI/)  

## Features

- **Batch conversion** of multiple documents in one go
- **Drag & drop** files or folders onto the app to populate the file list
- **Recursive folder scanning** for supported document types
- **9 output formats**: Plain Text, RTF, RTFD, DOCX, DOC, WordML, ODT, HTML, Web Archive
- **File info panel** showing document metadata (format, encoding, size, dates)
- **Quick Look** preview of selected documents
- **Reveal in Finder** for selected files
- **Options**: overwrite existing files, strip metadata

## Supported Input Formats

txt, rtf, rtfd, html/htm, doc, docx, odt, wordml, webarchive

## Requirements

- **macOS 14.6+**

## Usage

1. Launch `TextUtil.app` (or drop files/folders onto it)
2. Add documents using the **+** button
3. Select a document to see its info and Quick Look preview
4. Choose the output format and conversion options
5. Click **Convert** and pick a destination folder
