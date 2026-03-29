/// 환경변수에서 설정을 읽어오는 모듈
/// 비유: 건물 관리사무소 — 모든 설정 정보가 여기에

/// 앱 전체 설정을 담는 구조체
pub struct Config {
    pub db_url: String,
    pub port: u16,
}

impl Config {
    /// 환경변수에서 설정을 읽어옴
    /// SUPABASE_DB_URL 없으면 패닉 — DB 없이 계산엔진은 동작 불가
    pub fn from_env() -> Self {
        let db_url = std::env::var("SUPABASE_DB_URL")
            .expect("SUPABASE_DB_URL 환경변수가 필요합니다");

        let port = std::env::var("PORT")
            .unwrap_or_else(|_| "8081".to_string())
            .parse::<u16>()
            .expect("PORT는 유효한 포트 번호여야 합니다");

        Self { db_url, port }
    }
}
