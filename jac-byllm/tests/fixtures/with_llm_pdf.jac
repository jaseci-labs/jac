import from byllm {Model, PDFDoc, PDFPage}
import os;

glob llm = Model(
    model_name="gpt-4o",
);

def summarize_paper(paper: PDFDoc) -> str
    by llm();


obj Author {
    has first_name: str;
    has last_name: str;
    has email: str;
}

def get_authors(paper: PDFPage) -> list[Author] by llm();

with entry {
    research_paper = PDFDoc(
        os.path.join(
            os.path.dirname(__file__),
            'byllm_paper.pdf'
        )
    );
    # print(summarize_paper(research_paper));

    authors = get_authors(research_paper[0]);

    for author in authors {
        print(f"{author.first_name} {author.last_name} {author.email}");
    }
}
