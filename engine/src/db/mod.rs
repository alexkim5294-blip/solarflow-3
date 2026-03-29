/// DB 연결 풀 생성 모듈
/// 비유: 건물 수도 배관 — Supabase PostgreSQL에 연결하는 파이프라인

use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use std::time::Duration;

/// DB 연결 풀을 생성
/// max_connections=5: Free 플랜 내 운영 (직접 연결, pgBouncer 미사용)
pub async fn create_pool(db_url: &str) -> Result<PgPool, sqlx::Error> {
    tracing::info!("DB 연결 풀 생성 중...");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(Duration::from_secs(5))
        .connect(db_url)
        .await;

    match &pool {
        Ok(_) => tracing::info!("DB 연결 풀 생성 성공"),
        Err(e) => tracing::error!("DB 연결 풀 생성 실패: {}", e),
    }

    pool
}
