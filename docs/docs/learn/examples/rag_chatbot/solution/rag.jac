import os;
import from langchain_community.document_loaders {PyPDFDirectoryLoader, PyPDFLoader}
import from langchain_text_splitters {RecursiveCharacterTextSplitter}
import from langchain.schema.document {Document}
import from langchain_openai {OpenAIEmbeddings}
import from langchain_community.vectorstores.chroma {Chroma}


obj RagEngine {
    has file_path: str = "docs";
    has chroma_path: str = "chroma";

    def postinit {
        if not os.path.exists(self.file_path) {
            os.makedirs(self.file_path);
        }
        documents: list = self.load_documents();
        chunks: list = self.split_documents(documents);
        self.add_to_chroma(chunks);
        print("Documents loaded from", self.file_path);
    }

    def load_documents {
        document_loader = PyPDFDirectoryLoader(self.file_path);
        print("Loading documents from", document_loader);
        print("Document loader is", document_loader.load());
        return document_loader.load();
    }

    def load_document(file_path: str) {
        loader = PyPDFLoader(file_path);
        return loader.load();
    }

    def add_file(file_path: str) {
        documents = self.load_document(file_path);
        chunks = self.split_documents(documents);
        self.add_to_chroma(chunks);
    }

    def split_documents(documents: list[Document]) {
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=800,
        chunk_overlap=80,
        length_function=len,
        is_separator_regex=False);
        return text_splitter.split_documents(documents);
    }

    def get_embedding_function {
        embeddings = OpenAIEmbeddings();
        return embeddings;
    }

    def add_chunk_id(chunks: str) {
        last_page_id = None;
        current_chunk_index = 0;

        for chunk in chunks {
            source = chunk.metadata.get('source');
            page = chunk.metadata.get('page');
            current_page_id = f'{source}:{page}';

            if current_page_id == last_page_id {
                current_chunk_index +=1;
            } else {
                current_chunk_index = 0;
            }

            chunk_id = f'{current_page_id}:{current_chunk_index}';
            last_page_id = current_page_id;

            chunk.metadata['id'] = chunk_id;
        }

        return chunks;
    }

    def add_to_chroma(chunks: list[Document]) {
        db = Chroma(persist_directory=self.chroma_path, embedding_function=self.get_embedding_function());
        chunks_with_ids = self.add_chunk_id(chunks);

        existing_items = db.get(include=[]);
        existing_ids = set(existing_items['ids']);

        new_chunks = [];
        for chunk in chunks_with_ids {
            if chunk.metadata['id'] not in existing_ids {
                new_chunks.append(chunk);
            }
        }

        if len(new_chunks) {
            print('adding new documents');
            new_chunk_ids = [chunk.metadata['id'] for chunk in new_chunks];
            db.add_documents(new_chunks, ids=new_chunk_ids);
        } else {
            print('no new documents to add');
        }
    }

    def get_from_chroma(query: str,chunck_nos: int=5) {
        db = Chroma(
            persist_directory=self.chroma_path,
            embedding_function=self.get_embedding_function()
        );
        results = db.similarity_search_with_score(query,k=chunck_nos);
        return results;
    }

    def search(query: str, chunck_nos: int=5) {
        results = self.get_from_chroma(query=query, chunck_nos=chunck_nos);
        summary = "";
        for (doc, score) in results {
            page = doc.metadata.get('page');
            source = doc.metadata.get('source');
            chunk_txt = doc.page_content[:400];
            summary += f"{source} page {page}: {chunk_txt}\n";
        }
        return summary;
    }
}