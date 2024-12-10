import React, { useState } from 'react';
import { Editor } from 'react-draft-wysiwyg';
import { EditorState } from 'draft-js';
import 'react-draft-wysiwyg/dist/react-draft-wysiwyg.css';
import '../styles/DocumentEditor.css';

function DocumentEditor() {
  const [editorState, setEditorState] = useState(EditorState.createEmpty());

  return (
    <div className="document-editor">
      <div className="content-area">
        <Editor
          editorState={editorState}
          onEditorStateChange={setEditorState}
          wrapperClassName="wrapper-class"
          editorClassName="editor-class"
          toolbarClassName="toolbar-class"
          placeholder="Start writing your document..."
          toolbar={{
            options: ['inline', 'blockType', 'fontSize', 'list', 'textAlign', 'history'],
            inline: {
              inDropdown: false,
              options: ['bold', 'italic', 'underline'],
            },
            blockType: {
              inDropdown: true,
              options: ['Normal', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6'],
            },
          }}
        />
      </div>
    </div>
  );
}

export default DocumentEditor; 