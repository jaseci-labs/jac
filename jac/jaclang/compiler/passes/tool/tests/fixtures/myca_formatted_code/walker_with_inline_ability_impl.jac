walker update_timezone {
    has timezone_str: str;

    async can update_timezone with user_root entry {
        here.timezone_str = self.timezone_str;
        report here.timezone_str ;
    }
}
