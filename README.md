# soom

바탕화면 아이콘 숨기기 + 메뉴 막대 자동 숨기기.

https://github.com/user-attachments/assets/90f4fcb1-63d5-4746-b47a-d32fb0ece33a

## 사용법

1. 아이콘 클릭 
- 메뉴 막대 숨김
<img src='soomsoom/StatusIcons/wall-only.png' width = '100'>
  
- 메뉴 막대 보임
<img src='soomsoom/StatusIcons/cat-visible.png' width = '100'>

2. 우클릭
<img width="299" src="https://github.com/user-attachments/assets/634b05b6-b57d-4890-a651-45ffa78039f9" />

- ‘바탕화면 아이콘 표시’: 체크하면 표시, 해제하면 숨김.
- 메뉴 막대 ‘항상’ / ‘전체 화면일 때만’: 원하는 항목을 선택하면 체크 이동.
- 메뉴 막대 설정 다시 적용, 정보, 종료도 제공합니다.

## 수정

> [!NOTE]
> **아래는 AI가 작성함**

Xcode에서 `soomsoom.xcodeproj`를 열고 `soomsoom` 스킴을 실행하세요. 기존 최소 지원 버전인 macOS 26.2를 유지합니다.

Xcode Command Line Tools만 설치된 Apple Silicon Mac에서는 다음과 같이 빌드할 수 있습니다.

```sh
./build.sh
# 원하는 출력 폴더 지정
./build.sh /absolute/path/to/output
```

결과물은 `build/soom.app`입니다. 스크립트 빌드는 로컬 임시 서명이며 Apple 공증 배포본은 아닙니다.

## 시스템 설정 적용

Finder의 `CreateDesktop` 설정을 저장하고 현재 사용자의 Finder를 다시 시작해 바탕화면 아이콘을 반영합니다. Finder 윈도우를 강제로 닫는 AppleScript는 제거했습니다.

메뉴 막대는 전역 `_HIHideMenuBar`와 `AppleMenuBarVisibleInFullscreen` 설정을 저장한 다음, 데스크탑 변경 알림과 `AppleInterfaceFullScreenMenuBarVisibilityChangedNotification`을 각각 전송합니다. 전체 화면 알림은 이미 열린 전체 화면의 메뉴 막대 정책을 다시 읽게 하는 데 필요합니다.

다른 앱의 설정과 전역 설정을 바꿔야 하므로 Xcode 타깃의 App Sandbox는 꺼져 있습니다. 접근성·화면 기록·Automation 권한을 사용하지 않습니다. macOS 내부 설정에 의존하므로 OS 업데이트에 따라 호환성 확인이 필요합니다.
