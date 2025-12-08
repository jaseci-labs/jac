# database/models/comment.jac
# Comment model definition

obj Comment {
    has text: str;
    has author: str;
    
    def __repr__ -> str {
        return f"Comment({self.text} by {self.author})";
    }
}
