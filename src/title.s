| P-47II MD タイトル画面差し替え: 追加ルーチン
| ROM の空き領域 (0x085000-) に配置する. 元のコードからは patch.py が jsr/jmp で呼び出す.
|
| 元 ROM のアドレス
    .equ QUEUE_PTR,     0xff1470    | 描画キュー (VBlank でプレーンに転送)
    .equ PLANE_BASE,    0xff1000    | Plane A のベースオフセット
    .equ PAL_BUF,       0xffe04a    | パレットバッファ (VBlank で CRAM へ DMA)
    .equ FADE_MODE,     0xff9006    | パレットフェード: 2 = 開始要求
    .equ STATE,         0xff0002    | タイトルの状態番号
    .equ REVEAL_T,      0xff5208    | ロゴ出現のカウンタ
    .equ SLIDE_L,       0xff52aa    | 文字スライド (左から: 1 行目とメニュー)
    .equ SLIDE_R,       0xff52ac    | 文字スライド (右から: コピーライト)
    .equ CONT_COUNT,    0xff003c    | コンティニュー残り回数
    .equ HSCROLL_BUF,   0xff1060    | ライン H スクロール表 (224 ライン x 4 バイト)
    .equ DRAW_STRINGS,  0x020232    | 文字列リスト描画 (a0 = リスト)
    .equ PAL_FADE,      0x0230a4    | パレットフェード (a0 = 現在, a1 = 目標, d5 = 2^n フレーム)
    .equ PLANE_CLEAR,   0x020342    | 元の初期化: プレーン消去
    .equ VDP_DATA,      0xc00000
    .equ VDP_CTRL,      0xc00004
    .equ SCREEN_FLAGS,  0xffe002    | VDP レジスタ 1 の控え
    .equ TITLE_MAGIC,   0x50343754  | 'P47T': タイトルのタイルが VRAM に残っている目印

    .equ LOGO_OFS,      0x0284      | ロゴ左上 (Plane A 行 5, 列 2)
    .equ LOGO_COLS,     36
    .equ LOGO_ROWS,     8
    .equ LOGO_T0,       0x2a80      | 列 2 が出るカウンタ値 (旧ロゴ列 7 = 0x2d00 と同じ速さ, 同じ位置)

    .equ BAND1_TOP,     111         | 1 行目 + メニューのスクロール帯 (黒縁の分 1 ライン上から)
    .equ BAND1_LINES,   49          | 111-159
    .equ BAND2_LINES,   64          | 160-223 (コピーライト)

    .section .text

| ------------------------------------------------------------------
| タイトル初期化 (元: jsr PLANE_CLEAR). 画面表示オフ・割り込み禁止中に呼ばれる.
| 新しいタイル (ロゴ・文字・BG) と BG のマップ (Plane B) を VRAM に書き込む.
TitleInit:
    jsr     PLANE_CLEAR
    jsr     BlackRestoreRank
    movem.l d0/d7/a0-a1,-(sp)
    lea     TitleLoadTable,a1
1:  move.l  (a1)+,d0
    beq.s   3f
    movea.l (a1)+,a0
    move.w  (a1)+,d7
    move.l  d0,VDP_CTRL
2:  move.l  (a0)+,VDP_DATA
    dbra    d7,2b
    bra.s   1b
3:  move.l  #0x7ffc0003,VDP_CTRL    | VRAM 0xFFFC に目印を書く
    move.l  #TITLE_MAGIC,VDP_DATA
    movem.l (sp)+,d0/d7/a0-a1
    rts

| ------------------------------------------------------------------
| 画面初期化の共通処理の先頭 (元: 0x001c82 andi.w #$ffbf,$ffe002).
| タイトルの後なら, タイトル用に使った「元は 0 / 未使用だった領域」を 0 に戻す.
| (デモ・ゲームはプレーンを 128x32 にするため, 0xCE00- / 0xEE00- がマップとして使われる)
TitleExitClear:
    andi.w  #0xffbf,SCREEN_FLAGS
    move.w  SCREEN_FLAGS,VDP_CTRL   | 画面表示オフ (元の処理と同じ)
    move.w  sr,-(sp)
    ori.w   #0x0700,sr
    movem.l d0-d1/d7/a0,-(sp)
    move.l  #0x3ffc0003,VDP_CTRL    | VRAM 0xFFFC を読む
    move.l  VDP_DATA,d0
    cmpi.l  #TITLE_MAGIC,d0
    bne.s   9f
    lea     ExitClearTable,a0
    moveq   #0,d1
1:  move.l  (a0)+,d0
    beq.s   9f
    move.w  (a0)+,d7
    move.l  d0,VDP_CTRL
2:  move.l  d1,VDP_DATA
    dbra    d7,2b
    bra.s   1b
9:  movem.l (sp)+,d0-d1/d7/a0
    move.w  (sp)+,sr
    rts

| 0 に戻す領域: VRAM 書き込みコマンド.l, (long 数 - 1).w
ExitClearTable:
    dc.l    0x70000002              | 0xB000-0xB3FF (ウインドウ面)
    dc.w    0x400/4-1
    dc.l    0x7a800002              | 0xBA80-0xBFFF
    dc.w    0x580/4-1
    dc.l    0x4e000003              | 0xCE00-0xDFFF
    dc.w    0x1200/4-1
    dc.l    0x6e000003              | 0xEE00-0xFFFF (目印も消える)
    dc.w    0x1200/4-1
    dc.l    0

| ------------------------------------------------------------------
| ロゴを 1 列ずつ出す (元: 0x016b3a-0x016b7e, 爆発の横移動に合わせて 2 フレームに 1 列)
TitleReveal:
    move.w  REVEAL_T,d6
    subi.w  #LOGO_T0,d6
    bmi.s   9f
    lsr.w   #7,d6
    cmpi.w  #LOGO_COLS,d6
    bcc.s   9f
    add.w   d6,d6
    moveq   #LOGO_ROWS-1,d7
    lea     TitleLogoMap,a0
    movea.l QUEUE_PTR,a1
    move.w  PLANE_BASE,d0
    addi.w  #LOGO_OFS,d0
    add.w   d6,d0
    move.w  d0,(a1)+            | 転送先
    clr.w   (a1)+               | 横 1 タイル
    move.w  d7,(a1)+            | 縦 8 タイル
1:  move.w  (a0,d6.w),(a1)+
    addi.w  #LOGO_COLS*2,d6
    dbra    d7,1b
    move.l  a1,QUEUE_PTR
9:  jmp     0x016b84

| ------------------------------------------------------------------
| スキップ時: ロゴ全体を一度に描く (元: 0x016c6a-0x016c92)
TitleFullLogo:
    movea.l QUEUE_PTR,a0
    lea     TitleLogoMap,a1
    move.w  PLANE_BASE,d0
    addi.w  #LOGO_OFS,d0
    move.w  d0,(a0)+
    move.w  #LOGO_COLS-1,(a0)+
    move.w  #LOGO_ROWS-1,(a0)+
    move.w  #LOGO_COLS*LOGO_ROWS/2-1,d7
1:  move.l  (a1)+,(a0)+
    dbra    d7,1b
    move.l  a0,QUEUE_PTR
    rts

| ------------------------------------------------------------------
| コンティニュー表示 (元: 0x016c10-0x016c46)
TitleCont:
    lea     TitleContStrings,a0
    jsr     DRAW_STRINGS
    move.w  CONT_COUNT,d0
    cmpi.w  #9,d0
    bls.s   1f
    moveq   #9,d0
1:  lsl.w   #2,d0
    lea     TitleDigitTable,a0
    movea.l (a0,d0.w),a0
    jmp     DRAW_STRINGS

| ------------------------------------------------------------------
| 隠しメニュー: 通常メニューの黒縁タイルを消してから元の文字列を描く
TitleDbg:
    lea     TitleDbgClear,a0
    jsr     DRAW_STRINGS
    lea     0x017012,a0
    jmp     DRAW_STRINGS

| ------------------------------------------------------------------
| スキップ時 (元: 0x016d38, 最終位置へ飛ぶ前): コピーライト描画 + BG を含む全パレットへフェード
TitleSkip:
    lea     TitleCopyStrings,a0
    jsr     DRAW_STRINGS
    lea     PAL_BUF,a0
    lea     TitleNewPal,a1
    moveq   #5,d5
    move.w  #2,FADE_MODE
    jmp     PAL_FADE

| ------------------------------------------------------------------
| 文字スライド (元: 0x016d56-0x016d84).
| 初回にコピーライトを描き, 毎フレーム BG パレットをスライドの進み具合 (k/32) の明るさにする.
| (既存のフェード処理はフェード中に状態の進行を止めるため使わない)
TitleSlide:
    tst.w   SLIDE_L
    bne.s   1f
    lea     TitleCopyStrings,a0
    jsr     DRAW_STRINGS
1:  addi.w  #0x400,SLIDE_L
    subi.w  #0x400,SLIDE_R
    cmpi.w  #0x8000,SLIDE_L
    bcs.s   2f
    move.w  #0x8000,SLIDE_L
    move.w  #0x8000,SLIDE_R
    addq.w  #1,STATE
2:  move.w  SLIDE_L,d1
    lsr.w   #8,d1
    lsr.w   #2,d1               | k = 1..32
    bsr.s   SetBgBright
    bra.s   TitleBands

| BG パレット (PAL0, PAL2) を目標色 x k/32 にして PAL_BUF に書く. d1 = k
SetBgBright:
    lea     TitleNewPal,a0
    lea     PAL_BUF,a1
    bsr.s   1f
    lea     TitleNewPal+64,a0
    lea     PAL_BUF+64,a1
1:  moveq   #15,d7
2:  move.w  (a0)+,d0
    moveq   #0,d2
    move.w  d0,d3               | R (bit 1-3)
    lsr.w   #1,d3
    andi.w  #7,d3
    mulu    d1,d3
    lsr.w   #5,d3
    add.w   d3,d3
    or.w    d3,d2
    move.w  d0,d3               | G (bit 5-7)
    lsr.w   #5,d3
    andi.w  #7,d3
    mulu    d1,d3
    lsr.w   #5,d3
    lsl.w   #5,d3
    or.w    d3,d2
    move.w  d0,d3               | B (bit 9-11)
    lsr.w   #8,d3
    lsr.w   #1,d3
    andi.w  #7,d3
    mulu    d1,d3
    lsr.w   #5,d3
    lsl.w   #8,d3
    add.w   d3,d3
    or.w    d3,d2
    move.w  d2,(a1)+
    dbra    d7,2b
    rts

| ------------------------------------------------------------------
| ライン H スクロール表の更新 (元: 0x016d86-0x016dbc)
| 帯の境界を黒縁とメニュー位置に合わせて変更 (元: 112-143 / 144-223)
TitleBands:
    move.w  SLIDE_L,d0
    lsl.l   #8,d0
    lsl.l   #1,d0
    andi.l  #0x01ff0000,d0
    lea     HSCROLL_BUF+BAND1_TOP*4,a0
    moveq   #BAND1_LINES-1,d7
1:  move.l  d0,(a0)+
    dbra    d7,1b
    | コピーライトは 1 コマ先行させる (初回に末尾が画面左端へ回り込むのを防ぐ)
    move.w  SLIDE_R,d0
    cmpi.w  #0x8000,d0
    bls.s   2f
    subi.w  #0x400,d0
2:  lsl.l   #8,d0
    lsl.l   #1,d0
    andi.l  #0x01ff0000,d0
    moveq   #BAND2_LINES-1,d7
3:  move.l  d0,(a0)+
    dbra    d7,3b
    rts

    .include "title_data.s"
