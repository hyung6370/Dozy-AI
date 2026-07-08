//
//  AuthSheetDragLogic.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 7/3/26.
//

import CoreGraphics

/// AuthSheetView 의 드래그 스냅 규칙 — 뷰/제스처에서 분리한 순수 계산.
/// 세 offset(start/current/ending) 값만 받아 결정을 돌려주므로 단위 테스트가 가능하다.
struct AuthSheetDragLogic {

    /// "이 정도는 끌어야 열리고/닫힌다" 는 임계값.
    let dragThreshold: CGFloat

    /// 드래그를 끝냈을 때 시트가 취할 행동.
    enum DragEndAction: Equatable {
        /// 완전히 펼침 (endingOffsetY = -startOffsetY)
        case expand
        /// medium 으로 복귀 (endingOffsetY = 0)
        case collapse
        /// 시트 닫기
        case dismiss
        /// 현재 위치 유지
        case stay
    }

    /// onChanged 용 — 위쪽 한계 클램프.
    /// 펼침 위치보다 더 올라가지 않게 translation 하한을 -(start + ending) 으로 자른다.
    /// (펼친 상태에선 하한이 0 이 되어 아래로만 끌린다)
    func clampedDragOffset(
        translation: CGFloat,
        startOffsetY: CGFloat,
        endingOffsetY: CGFloat
    ) -> CGFloat {
        max(translation, -(startOffsetY + endingOffsetY))
    }

    /// onEnded 용 — 임계값 분기.
    /// - 위로 임계값 이상: 펼침
    /// - 펼친 상태(ending != 0)에서 아래로 임계값 이상: medium 복귀
    /// - medium(ending == 0)에서 아래로 임계값 이상: 닫기 (로그인 요청 중엔 잠금)
    func endAction(
        currentDragOffsetY: CGFloat,
        endingOffsetY: CGFloat,
        isLoading: Bool
    ) -> DragEndAction {
        if currentDragOffsetY < -dragThreshold {
            return .expand
        } else if endingOffsetY != 0, currentDragOffsetY > dragThreshold {
            return .collapse
        } else if endingOffsetY == 0, currentDragOffsetY > dragThreshold, !isLoading {
            return .dismiss
        }
        return .stay
    }
}
