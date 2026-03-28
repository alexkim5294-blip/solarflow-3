package middleware

import "context"

// contextKey — context에 저장할 키의 타입
// 비유: 사원증에 부착하는 태그 종류 — "이름표", "부서표", "이메일표" 등
type contextKey string

const (
	// 비유: 사원증의 각 태그 이름
	keyUserID         contextKey = "user_id"
	keyUserRole       contextKey = "user_role"
	keyUserEmail      contextKey = "user_email"
	keyAllowedModules contextKey = "allowed_modules"
)

// SetUserContext — 인증된 사용자 정보를 context에 저장
// 비유: 보안 게이트를 통과한 사람에게 사원증을 발급하는 것
func SetUserContext(ctx context.Context, userID, role, email string, allowedModules []string) context.Context {
	ctx = context.WithValue(ctx, keyUserID, userID)
	ctx = context.WithValue(ctx, keyUserRole, role)
	ctx = context.WithValue(ctx, keyUserEmail, email)
	ctx = context.WithValue(ctx, keyAllowedModules, allowedModules)
	return ctx
}

// GetUserID — context에서 사용자 ID를 꺼냄
// 비유: 사원증에서 사번을 읽는 것
func GetUserID(ctx context.Context) string {
	val, ok := ctx.Value(keyUserID).(string)
	if !ok {
		return ""
	}
	return val
}

// GetUserRole — context에서 사용자 역할을 꺼냄
// 비유: 사원증에서 직급을 읽는 것
func GetUserRole(ctx context.Context) string {
	val, ok := ctx.Value(keyUserRole).(string)
	if !ok {
		return ""
	}
	return val
}

// GetUserEmail — context에서 사용자 이메일을 꺼냄
// 비유: 사원증에서 이메일 주소를 읽는 것
func GetUserEmail(ctx context.Context) string {
	val, ok := ctx.Value(keyUserEmail).(string)
	if !ok {
		return ""
	}
	return val
}

// GetAllowedModules — context에서 허용된 모듈 목록을 꺼냄
// 비유: 사원증에서 출입 허용 구역 목록을 읽는 것
func GetAllowedModules(ctx context.Context) []string {
	val, ok := ctx.Value(keyAllowedModules).([]string)
	if !ok {
		return nil
	}
	return val
}
