import logging;

glob logger = logging.getLogger(__name__),
     VERIFY_PURPOSE: str = 'verify',
     RESET_PURPOSE: str = 'reset',
     VERIFY_SCOPE: str = 'send-verification',
     RESET_SCOPE: str = 'forgot-password',
     MAIL_WINDOW_SECONDS: int = 3600;

enum MailOutcome {
    SENT = 'sent',
    FAILED = 'failed',
    DISABLED = 'disabled',
    LIMITED = 'limited'
}

obj MailResult {
    has outcome: MailOutcome,
        retry_after: int = 0;

    def sent -> bool;
}


def verification_problems(mode: str, emailer: any) -> list[str];


def mail_body(action: str, link: str, ttl: int, footer: str = '') -> str;


def recovery_email(user: dict[str, any]) -> (dict[str, any] | None);

obj IdentityMailer {
    has emailer: any = None;

    def ready -> bool;
    def link(user_id: str, purpose: str, address: str, ttl: int, template: str) -> str;
    def claim(scope: str, actor: str, per_hour: int) -> MailResult | None;
    def send_verification(
        user_id: str, identity: dict[str, any], source_ip: str = ''
    ) -> MailResult;

    def announce(user: dict[str, any], source_ip: str = '', address: str = '');
    def send_reset(user: dict[str, any], source_ip: str = '') -> MailResult;
}
