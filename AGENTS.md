# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-28
**Last Updated:** 2026-01-30
**Commit:** n/a
**Branch:** n/a

---

## OVERVIEW

macOS image viewer & manager with AI-powered tagging, non-destructive XMP metadata, Gypsum design system. XMP + thumbnails are stored under app-managed storage (not in original folders). Swift 6.2 + SwiftUI + Vision Framework.

---

## RULE

If create new file(s), tell the user to add the files to the xcode project manually. Agent are hard to add the new files into the xcode project

## STRUCTURE

```
./
├── SpectasiaCore/            # SwiftPM package
│   ├── Sources/Core/         # Core services (12 files)
│   └── Tests/CoreTests/      # Core tests (9 files)
├── UI/                       # SwiftUI views + Gypsum design system
├── Resources/                # Assets, localization
├── Spectasia/                # App target resources
├── SpectasiaApp.swift         # @main entry point
└── Spectasia.xcodeproj        # Xcode project
```

---

## TODO LIST (2026-01-30 통합)

### ✅ 완료된 기능

#### Core 서비스

- [x] `AppConfig` - UserDefaults 기반 설정 관리
- [x] `ImageRepository` + `ObservableImageRepository` - 이미지 컬렉션 관리
- [x] `ThumbnailService` - 멀티사이즈 썸네일 생성 (120/480/1024px)
- [x] `XMPService` - 비파괴적 XMP 사이드카 (ratings/tags)
- [x] `AIService` - Vision Framework 기본 분류 (`VNClassifyImageRequest`)
- [x] `FileMonitorService` - FSEvents 기반 파일 모니터링
- [x] `PermissionManager` - Security-Scoped Bookmarks
- [x] `BackgroundCoordinator` - Actor 기반 백그라운드 작업
- [x] `MetadataStore` - XMP/썸네일 경로 인덱스 관리
- [x] 34개 테스트 통과

#### UI 기본 구조

- [x] `SpectasiaLayout` - 3패널 레이아웃 (사이드바/콘텐츠/상세)
- [x] `ContentView` - 메인 뷰 (Core 연결됨)
- [x] `ImageGridView` - 썸네일 그리드 뷰
- [x] `SingleImageView` - 단일 이미지 뷰 (기본)
- [x] `MetadataPanel` / `DetailPanel` - 메타데이터 패널
- [x] `GypsumDesignSystem` - 디자인 시스템 정의
- [x] `ToastCenter` - 토스트 알림 시스템
- [x] `SpectasiaCommands` - 메뉴 명령어

#### 국제화

- [x] 다국어 지원 (영어/한국어)
- [x] `AppLanguage` enum 구현

---

### 🚧 진행 중 / 부분 완료

#### UI 연결 (Phase 1)

- [x] ContentView-ImageRepository 연결
- [x] DirectoryScanManager 기반 디렉토리 트리 + 자동 스캔 도구 추가
- [x] 파일 모니터링 이벤트와 이미지 선택 상태 정합성 확보
- [x] "모니터링" 토글 제거 및 기본 감시(항상 켬) 전환
- [x] Sidebar 순서를 Settings → 디렉토리 추가 → Directory tree로 정리하고 트리 전역 확장/축소/전체 재스캔 버튼과 메타데이터 상태 메시지를 노출
- [x] Metadata panel now allows editing tags, shows thumbnail/XMP status, and keeps metadata timestamps in sync with background indexing
- [x] 데이터 바인딩 최적화 (선택/상태 분리 완료)
- [x] Sidebar shows permission status and a “Grant Full Disk Access” shortcut to open System Settings when extra rights are required
- [x] Sidebar also lists the currently authorized directories so you can see which bookmarks are in scope while developing
- [x] View-mode picker, enriched list view, and single-image filmstrip/zoom placeholder now live so Phase 2 view-mode work is underway
- [x] Settings view reworked with Gypsum cards, Save/Cancel/Apply buttons, and a language grid
- [x] Initial directory UX now manual—Starts with a “no folder” placeholder and relies on sidebar picker
- [x] Directory tree rows show file stats and the sidebar has dividers, multi-add cues, and accessible-directory list
- [x] Viewer area shows view-mode picker and single-image filmstrip placeholder

#### 설정 화면

- [x] `SettingsView` 기본 구현
- [x] **일반적인 3버튼 패턴 없음** (저장/취소/적용)
- [x] **Gypsum 디자인 미적용**
- [x] **App Language Grid 레이아웃 이상**

---

### ❌ 미구현 기능

#### 🔴 사용자 지적 이슈 (2026-01-30)

1. **앱 시작 시 디렉토리 선택 UX**
   - [x] 감시 디렉토리 없을 때 "없음" 표시 및 안내
   - [x] 사용자가 수동으로 선택하도록 변경 (자동 다이얼로그 X)

2. **Settings 창 개선**
   - [ ] 일반적인 3버튼 패턴 추가 (저장/취소/적용)
   - [ ] Gypsum 디자인 시스템 적용
   - [ ] App Language 섹션 Grid 레이아웃 수정

3. **Sidecar(사이드바) 영역 기능 및 디자인**
   - [ ] 각 영역별 수평선으로 구분
   - [ ] Setting 버튼 최상단, "폴더" 타이틀 하단 배치
   - [ ] 감시 디렉토리 다중 지원
   - [ ] 디렉토리 트리 구조 구현
   - [ ] 환경설정에 감시 디렉토리 목록 저장
   - [ ] 트리 최상단에 '+' 메뉴 (디렉토리 추가용)
   - [ ] 트리 노드에 이미지 합계 표시 (작은 글씨)

4. **중앙 Viewer 화면 개선**
   - [ ] 썸네일 보기 / 리스트 보기 / 큰 이미지 보기 전환 메뉴
   - [ ] 리스트 보기 구현 (파일명, 크기, 생성일, 별표, XMP 메타데이터)
   - [ ] 큰 이미지 보기 구현 (필름스트립, 줌/팬)

5. **키보드 단축키**
   - [ ] 뷰 모드 전환 (Cmd+1/2/3)
   - [ ] 별점 단축키 (Ctrl+1-5, Ctrl+0)
   - [ ] 이미지 네비게이션 (←/→ 화살표)
   - [ ] 전체화면 (Cmd+F, Escape)
   - [ ] 화면 맞춤/원본 (Cmd+0/9)

---

#### Phase 2: 뷰 모드 완성

- [ ] 리스트 뷰 TableView 구현 (파일명/크기/날짜/별점/포맷/태그 컬럼)
- [ ] 컬럼 정렬 기능
- [ ] 다중 선택 (Shift+클릭, Cmd+클릭)
- [ ] 단일 이미지 뷰 필름스트립
- [ ] 단일 이미지 뷰 좌우 화살표 네비게이션
- [ ] EXIF 오버레이 (위치 선택: 상/하/좌/우)
- [ ] 뷰 모드 전환 State Machine
- [ ] 썸네일 크기 조절 UI (작음/중간/큼)

#### Phase 3: AI 기능 확장

- [ ] 얼굴 감지 (`VNDetectHumanFaceRectanglesRequest`)
- [ ] 동물 감지 (`VNRecognizeAnimalsRequest`)
- [ ] 객체 감지/태깅
- [ ] 분위기/카테고리 분석
- [ ] AI 자동 분석 모드 (`aiAutoAnalysis` 토글)
- [ ] AI 분석 진행 추적 UI

#### Phase 4: 앨범 시스템

- [ ] XMP 앨범 메타데이터 확장
- [ ] 태그 기반 앨범
- [ ] 날짜 기반 앨범 (연도/월/일)
- [ ] 위치 기반 앨범 (GPS)
- [ ] 사람 기반 앨범 (얼굴 감지 활용)
- [ ] 반려동물 기반 앨범
- [ ] 앨범 편집 (삭제/이름변경/병합/커버)

#### Phase 5: UX 향상

- [ ] 트랙패드 제스처 (two-finger swipe, double-tap)
- [ ] 메뉴바 통합 (File/View/Tools/Help)
- [ ] 백그라운드 작업 진행 상태 UI
- [ ] 작업 큐 표시
- [ ] 메뉴바 진행 요약 ("N/M 완료")

#### Phase 6: 기술적 개선

- [ ] ICC 프로필 보존 (색상 관리)
- [ ] HDR 이미지 지원 및 톤 매핑
- [ ] 캐시 정리 전략 (LRU, 크기 제한)
- [ ] XMP 파싱 개선 (XMLParser 사용)

---

### ⚠️ 알려진 빌드 이슈

**Xcode 빌드 실패 (CRITICAL)**

- 링커 오류: `symbol(s) not found for architecture arm64`
- 상태: 미해결 (30+ 빌드 시도)
- 원인 추정: Xcode 프로젝트 설정 문제 또는 파일 경로 불일치
- 권장 조치: Xcode IDE에서 프로젝트 파일 참조 수정 필요

---

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| App entry | `SpectasiaApp.swift` | SwiftUI @main |
| Core services | `SpectasiaCore/Sources/Core/*.swift` | Config, Monitor, XMP, Thumbnail, AI, Repo, Permission |
| UI components | `UI/*.swift` | Views, design system |
| Design tokens | `UI/GypsumDesignSystem.swift` | Colors, fonts, GypsumCard, GypsumButton |
| Package definition | `Package.swift` | Swift 6.2, macOS 13+ |
| Tests | `SpectasiaCore/Tests/CoreTests/*.swift` | TDD for all services |

---

## CONVENTIONS

- **Package structure**: Swift Package Manager for `SpectasiaCore` library
- **SwiftUI views**: Separate from Core package, in `UI/` directory
- **TDD**: All core services have corresponding test files
- **Design system**: Gypsum aesthetic (matte finish, soft shadows)
- **Permissions**: Security-Scoped Bookmarks
- **Metadata**: Non-destructive XMP sidecars only
- **Language**: `AppLanguage` enum (en, ko)

---

## COMMANDS

```bash
# Build Core package
swift build

# Run tests (34 tests total)
swift test

# Build GUI (requires Xcode)
open Spectasia.xcodeproj  # Press ⌘R
```

---

## NOTES

- **GUI wiring started**: `ContentView` and `SpectasiaLayout` connected to Core, but UI panels partial.
- **Test coverage**: Core tests in `SpectasiaCore/Tests/CoreTests/`.
- **Permission flow**: `PermissionManager.requestDirectoryAccess()` → bookmark storage.
- **Entry point**: `SpectasiaApp` creates and injects `AppConfig`, `ObservableImageRepository`, `PermissionManager`.
