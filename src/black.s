| P-47II MD BLACK LABEL (裏モード): 難易度変更ルーチン
| Rank ($fffc06) = 3 のときだけ動作する. Rank 0-2 (Easy/Normal/Hard) は元の処理のまま.
|
    .equ RANK,          0xfffc06    | 0=Easy 1=Normal 2=Hard 3=BLACK
    .equ RANK_BLACK,    3
    .equ FRAME_CNT,     0xff500e    | 毎フレーム +1 されるカウンタ
    .equ BUL_MASK,      0xff78c6    | 敵弾プールの使用中ビット
    .equ BUL_POOL_N,    0xff4c08    | 敵弾プールの数 - 1 (通常時)
    .equ BOSS_MODE,     0xff6006    | ボス戦中は 0 以外
    .equ BUL_POOL_N_B,  0xff6014    | 敵弾プールの数 - 1 (ボス戦)

    .equ PAD_STATE,     0xffe032    | パッド (上位バイト: 押している / 下位: 押した瞬間)
    .equ SAVED_RANK,    0xfffc1e    | BLACK で遊ぶ前の Rank (未使用 RAM). 0xffff = なし
    .equ BUL_SPAWN_BODY, 0x0117ae   | 敵弾生成の本体 (元: 0x0117a6 movem / 0x0117aa lea の後)
    .equ HITBOX_TABLE,  0x001462    | 当たり判定の表 (種類 x 8 バイト: y0,y1,x0,x1)

| 調整値
    .equ BL_POOL_N,       31        | 敵弾プールの数 - 1 (32 発. 使用中ビットが 32 ビットのため上限)

| BLACK 用 RAM (全ステージで未使用を確認した領域)
    .equ BL_POOL,       0xffb400    | 敵弾プール 32 x 0x40 (元: 0xff78ca, 最大 23 発分). 0xffa326-0xffae65 はボス戦で使われる
    .equ BL_BSAT,       0xff3300    | 敵弾のスプライト表 32 枠
    .equ BL_OSAT,       0xff3400    | VDP へ送るスプライト表 (詰め直し後) 80 枠
    .equ BL_OLDK,       0xff3700    | 元の敵弾スプライト枠の先頭番号 (通常時)
    .equ BL_OLDK_B,     0xff3702    | 同 (ボス戦)
    .equ BL_DMASRC,     0xff3704    | スプライト表 DMA の転送元 (VDP レジスタ 22/21 の値)
    .equ BL_FIRSTW,     0xff3708    | DMA 後に書き直す先頭ワード
    .equ SAT_BUF,       0xff3002    | 元のスプライト表 (80 枠)
    .equ SCENE,         0xff0000    | 場面番号 (3 = ゲーム中)
    .equ WAIT_VBLANK,   0x000326
    .equ BL_ORIG_WORDS, 0xff370a    | このフレームの出現リストの元の長さ (ワード数)
    .equ BL_PAT,        0xff370c    | ボスの攻撃パターン: 今のパターン (PatTable の番号)
    .equ BL_PAT_ANG,    0xff370e    | ボスの攻撃パターン: 回転の角度 (0-35, 10 度単位)
    .equ BL_PAT_T,      0xff3710    | ボスの攻撃パターン: パターンの残りフレーム
    .equ BL_BIG_I,      0xff3712    | 大型ボス: 弾を出す部品 (当たり判定の表の番号)
    .equ BL_PAT_W,      0xff3716    | ボスの攻撃パターン: 次の射撃までのフレーム
    .equ BL_BIG_PAT,    0xff371c    | 大型ボス: 部品を選んだときのパターン
    .equ BL_DBG_BLACK,  0xff3714    | 隠しメニューの BLACK (0 = OFF, 1 = ON). タイトル初期化で OFF
    .equ BL_SHOOTER,    0xff3690    | 大型ボスの弾を出す仮の敵 (0x40 バイト. 位置だけ使う)
    .equ BIG_BOSS,      0xff002c    | 大型ボスの間は 0 以外 (敵・敵弾の処理が止まる)
    .equ HIT_LIST,      0xff818a    | 自機に当たる物の当たり判定の表 (種類.w, y.w, x.w) x n, 0xffff で終わり
    .equ HIT_LIST_MAX,  80
    .equ HIT_LIST_PTR,  0xff7ef4    | 表の書き込み位置 (敵の処理の後, 敵弾の処理が続きを書く)
    .equ PLAYER,        0xff4002    | 自機 ($0e / $10 が位置)
    .equ BL_BOSS_OBJ,   0xff3718    | ボス戦のボス (ボス戦開始時の敵. 0 = なし)
    .equ BL_QUEUE,      0xff3720    | 追加編隊の待ち行列: (敵コード.w, 残りフレーム.w) x 16
    .equ BL_QUEUE_N,    16
    .equ SPAWN_LIST,    0xff000a    | このフレームに出す敵コードのリスト (0 で終わり)
    .equ OBJ_DUP,       0x48        | 敵オブジェクト内の未使用欄: bit 0 = 追加編隊, bit 1 = 飛行ザコ
    .equ BL_TCACHE,     0xff3780    | 色違いタイルの一覧: (元のタイル.w, 枚数.w, コピー先.w) x 24
    .equ BL_TCACHE_N,   24
    .equ BL_TFREE_A,    0xff3770    | コピー先 A の次の空き (タイル番号)
    .equ BL_TFREE_B,    0xff3772    | コピー先 B の次の空き
    .equ TILE_A0,       0x05d4      | コピー先 A: VRAM 0xBA80-0xBFFF (スプライト表の後ろ, 44 枚)
    .equ TILE_A1,       0x0600
    .equ TILE_B0,       0x058c      | コピー先 B: VRAM 0xB180-0xB3FF (ウインドウ面の表示しない行, 20 枚)
    .equ TILE_B1,       0x05a0

| ボス・中ボスのリング弾 (BLACK)
    .equ DIRS,          36          | 向きの刻み (10 度). 向きの番号が 1 減ると画面で時計回りに 10 度

| 追加編隊の調整値
    .equ BL_DUP_DELAY,  40          | 元の敵から何フレーム遅れて出すか

| ------------------------------------------------------------------
| 敵弾生成 (元: 0x0117a6). d2 = 弾の種類, d3/d4 = 速度 (1/16 ドット), a0 = 撃った敵.
| 元の処理は a2 (生成した弾) 以外のレジスタを保存する.
| BLACK: 角度をずらした弾を最大 4 発追加 (5-way). 特殊な弾 (種類 1 以上) は増やさない.
| プールの空きが少ないときは減らす.
BlackBulletSpawn:
    cmpi.w  #RANK_BLACK,RANK
    beq.s   1f
OrigBulletSpawn:
    movem.l d0-d7/a0-a1/a3-a6,-(sp)
    lea     0x00f192,a1
    jmp     BUL_SPAWN_BODY
1:  movem.l d0-d1/d3-d7/a1/a3,-(sp)
    tst.w   BOSS_MODE
    beq.s   0f
    bsr.w   BossPoolFix
0:  bsr.s   OrigBulletSpawn         | 本来の弾
    move.l  a2,-(sp)
    tst.w   d2
    bne.s   9f                      | 特殊な弾 (ミサイル・機雷など) は増やさない
    move.w  d3,d6                   | 元の速度
    move.w  d4,d7
    lea     SpreadTable,a3          | 角度をずらした弾を足す
2:  move.w  (a3)+,d5                | 必要な空き数 (0 = 表の終わり)
    beq.s   9f
    bsr.w   FreeBulletSlots
    cmp.w   d5,d0
    blt.s   9f
    bsr.w   RotSpawn                | +角度
    bsr.w   RotSpawn                | -角度
    bra.s   2b
9:  move.l  (sp)+,a2
    movem.l (sp)+,d0-d1/d3-d7/a1/a3
    rts

| ボス戦: ボスの攻撃が敵弾の数と表の位置 ($ff6014 / $ff6016) を書き換えたら, BLACK の設定 (32 発, 専用の表) に戻す.
| 元の表の位置に描かれていた弾は消す
BossPoolFix:
    cmpi.l  #BL_BSAT,0xff6016
    beq.s   9f
    movem.l d7/a0,-(sp)
    movea.l 0xff6016,a0
    move.w  BUL_POOL_N_B,d7
    cmpi.w  #BL_POOL_N,d7
    bhi.s   8f
    cmpa.l  #SAT_BUF,a0
    bcs.s   8f
    cmpa.l  #SAT_BUF+80*8,a0
    bcc.s   8f
1:  clr.l   (a0)+
    clr.l   (a0)+
    cmpa.l  #SAT_BUF+80*8,a0
    dbcc    d7,1b
8:  move.l  #BL_BSAT,0xff6016
    move.w  #BL_POOL_N,BUL_POOL_N_B
    movem.l (sp)+,d7/a0
9:  rts

| ------------------------------------------------------------------
| ボス・中ボス・大型ボスの追加の攻撃 (BLACK). PatTable のパターンを順に繰り返す.
| 1 パターン = (長さ, 射撃の間隔, 最初の待ち, 向きの決め方, 速さ, 必要な空き, 向きのずらし表)

| 毎フレーム: タイマーを進め, 撃つフレームなら a1 = パターン, d0 = 1 (Z=0). d0/a1 を使う
BossTick:
    subq.w  #1,BL_PAT_T
    bgt.s   1f
    move.w  BL_PAT,d0               | 次のパターン
    addq.w  #1,d0
    cmpi.w  #PAT_N,d0
    bcs.s   0f
    moveq   #0,d0
0:  move.w  d0,BL_PAT
    lea     PatTable,a1
    lsl.w   #4,d0
    adda.w  d0,a1
    move.w  (a1),BL_PAT_T           | 長さ
    move.w  4(a1),BL_PAT_W          | 最初の待ち
1:  move.w  BL_PAT,d0
    lea     PatTable,a1
    lsl.w   #4,d0
    adda.w  d0,a1
    subq.w  #1,BL_PAT_W
    bgt.s   8f
    move.w  2(a1),BL_PAT_W          | 射撃の間隔
    moveq   #1,d0
    rts
8:  moveq   #0,d0
    rts

| パターン a1 で 1 回撃つ. a0 = 撃つ敵 (位置は弾の生成と同じ計算). d0-d7/a1-a3 を壊さない
BossShoot:
    movem.l d0-d7/a1-a3,-(sp)              | (a2 は弾の生成が返すので保存する)
    bsr.w   FreeBulletSlots
    cmp.w   10(a1),d0               | 空きが足りなければ撃たない
    blt.s   9f
    move.w  6(a1),d0                | 向きの決め方
    btst    #0,d0
    beq.s   1f
    bsr.w   AimDir                  | 自機狙い -> d0
    move.w  d0,d5
    bra.s   2f
1:  move.w  BL_PAT_ANG,d5           | 回転: 撃つたびに時計回りに 10 度
    subq.w  #1,d5
    bpl.s   0f
    moveq   #DIRS-1,d5
0:  move.w  d5,BL_PAT_ANG
2:  move.w  8(a1),d6                | 速さ
    movea.l 12(a1),a1               | 向きのずらし表 (0x7fff で終わり)
3:  move.w  (a1)+,d0
    cmpi.w  #0x7fff,d0
    beq.s   9f
    add.w   d5,d0
    move.w  d6,d1
    bsr.w   FireDir
    bra.s   3b
9:  movem.l (sp)+,d0-d7/a1-a3
    rts

| d0 = 向き (10 度単位. 範囲外も可), d1 = 速さ で通常弾を 1 発. a0 = 撃つ敵. d0-d4/a3 を使う
FireDir:
    ext.l   d0
    divs.w  #DIRS,d0
    swap    d0
    tst.w   d0
    bpl.s   1f
    addi.w  #DIRS,d0
1:  lsl.w   #2,d0
    lea     RingTable,a3
    move.w  (a3,d0.w),d3
    muls.w  d1,d3
    asr.l   #8,d3
    move.w  2(a3,d0.w),d4
    muls.w  d1,d4
    asr.l   #8,d4
    moveq   #0,d2
    bra.w   OrigBulletSpawn

| a0 から自機への向きに一番近い向きの番号 -> d0 (d1-d7/a3 は壊さない)
AimDir:
    movem.l d1-d7/a3,-(sp)
    move.w  0x32(a0),d3             | 撃つ位置 (弾の生成と同じ: 位置 + 大きさ / 2)
    lsr.w   #1,d3
    add.w   0x1a(a0),d3
    lsr.w   #4,d3
    move.w  0x34(a0),d4
    lsr.w   #1,d4
    add.w   0x1c(a0),d4
    lsr.w   #4,d4
    move.w  PLAYER+0x0e,d1          | 自機の位置 (0x010958 と同じ計算)
    addi.w  #0x80,d1
    lsr.w   #4,d1
    sub.w   d3,d1                   | 縦の差
    move.w  PLAYER+0x10,d2
    addi.w  #0x140,d2
    lsr.w   #4,d2
    sub.w   d4,d2                   | 横の差
    lea     RingTable,a3
    moveq   #0,d0                   | 一番近い向き
    move.l  #0x80000000,d5          | その内積
    moveq   #0,d6                   | 向き
1:  move.w  (a3)+,d3
    muls.w  d1,d3
    move.w  (a3)+,d4
    muls.w  d2,d4
    add.l   d4,d3
    cmp.l   d5,d3
    ble.s   2f
    move.l  d3,d5
    move.w  d6,d0
2:  addq.w  #1,d6
    cmpi.w  #DIRS,d6
    bcs.s   1b
    movem.l (sp)+,d1-d7/a3
    rts

| ボス・中ボス戦 (毎フレーム, BlackEnemySys から). ボス (BL_BOSS_OBJ) が画面内にいれば攻撃パターン
BossAttack:
    movem.l d0-d1/a0-a1,-(sp)
    bsr.w   BossTick
    beq.s   9f
    movea.l BL_BOSS_OBJ,a0
    move.w  0x32(a0),d0             | 画面内か (中心で判定)
    lsr.w   #1,d0
    add.w   0x1a(a0),d0
    lsr.w   #4,d0
    cmpi.w  #128+8,d0
    bcs.s   9f
    cmpi.w  #128+216,d0
    bcc.s   9f
    move.w  0x34(a0),d0
    lsr.w   #1,d0
    add.w   0x1c(a0),d0
    lsr.w   #4,d0
    cmpi.w  #128+8,d0
    bcs.s   9f
    cmpi.w  #128+312,d0
    bcc.s   9f
    bsr.w   BossShoot
9:  movem.l (sp)+,d0-d1/a0-a1
    rts

| ------------------------------------------------------------------
| 大型ボス (各面の最後のボス. ボス戦の扱いにならず, 元の処理では敵弾も止まる) の処理
| (元: 0x0227ba / 0x0227d6 / 0x022806 jsr $2f6aa. 面ごとの大型ボスの処理へ分かれる入口).
| BLACK: 攻撃パターンを, 大型ボスが作った当たり判定の表 ($ff818a) の部品から撃つ.
| 弾を出すのは, 画面内でボスのスプライトが重なっている部品だけ (見えない当たり判定からは撃たない).
| パターンが変わるたびに次の部品へ移る.
BlackBigBoss:
    jsr     0x02f6aa
    cmpi.w  #RANK_BLACK,RANK
    bne.w   9f
    movem.l d0-d7/a0-a3,-(sp)
    bsr.w   BossTick
    beq.w   8f
    move.w  BL_BIG_I,d2
    move.w  BL_PAT,d0
    cmp.w   BL_BIG_PAT,d0
    beq.s   0f
    move.w  d0,BL_BIG_PAT
    addq.w  #1,d2                   | パターンが変わった: 次の部品から探す
0:  lea     HIT_LIST,a2             | 表の長さ -> d1
    moveq   #0,d1
1:  cmpi.w  #0xffff,(a2)
    beq.s   2f
    addq.l  #6,a2
    addq.w  #1,d1
    cmpi.w  #HIT_LIST_MAX,d1
    bcs.s   1b
    bra.w   8f
2:  tst.w   d1
    beq.w   8f
    lea     HIT_LIST,a2
    move.w  d1,d7
    subq.w  #1,d7                   | 調べる回数 - 1
    subq.w  #1,d2
4:  addq.w  #1,d2
    cmp.w   d1,d2
    bcs.s   5f
    moveq   #0,d2
5:  move.w  d2,d3
    mulu    #6,d3
    move.w  (a2,d3.w),d0            | 種類 (0 = 無効, 最上位ビット = 弾など)
    beq.s   6f
    bmi.s   6f
    move.w  2(a2,d3.w),d4           | 位置 ($1a / 16, $1c / 16)
    move.w  4(a2,d3.w),d5
    addq.w  #4,d4
    addq.w  #4,d5
    cmpi.w  #128+8,d4               | 画面内だけ
    bcs.s   6f
    cmpi.w  #128+216,d4
    bcc.s   6f
    cmpi.w  #128+8,d5
    bcs.s   6f
    cmpi.w  #128+312,d5
    bcc.s   6f
    bsr.s   SpriteAt                | ボスのスプライトが重なっているか
    bne.s   7f
6:  dbra    d7,4b
    bra.s   8f
7:  move.w  d2,BL_BIG_I
    lea     BL_SHOOTER,a0
    lsl.w   #4,d4
    move.w  d4,0x1a(a0)
    lsl.w   #4,d5
    move.w  d5,0x1c(a0)
    clr.w   0x2c(a0)
    clr.l   0x32(a0)
    clr.l   0x3a(a0)
    bsr.w   BossShoot
8:  movem.l (sp)+,d0-d7/a0-a3
9:  rts

| (d4, d5) = (縦, 横) (スプライト表の座標) に元のスプライト表のスプライトが重なっていれば d0 = 1 (Z=0).
| d0/d6/a3 を使う
SpriteAt:
    movem.l d1-d3/d7,-(sp)
    lea     SAT_BUF,a3
    moveq   #80-1,d7
1:  move.w  (a3),d0                 | y
    beq.s   2f
    move.w  2(a3),d1                | 大きさ
    move.w  6(a3),d2                | x
    andi.w  #0x1ff,d2
    cmp.w   d0,d4
    blt.s   2f
    move.w  d1,d3                   | 高さ = (縦のタイル数) x 8
    andi.w  #0x0300,d3
    lsr.w   #5,d3
    addq.w  #8,d3
    add.w   d3,d0
    cmp.w   d0,d4
    bge.s   2f
    cmp.w   d2,d5
    blt.s   2f
    andi.w  #0x0c00,d1              | 幅 = (横のタイル数) x 8
    lsr.w   #7,d1
    addq.w  #8,d1
    add.w   d1,d2
    cmp.w   d2,d5
    bge.s   2f
    moveq   #1,d0
    bra.s   9f
2:  addq.l  #8,a3
    dbra    d7,1b
    moveq   #0,d0
9:  movem.l (sp)+,d1-d3/d7
    rts

| 攻撃パターン: 長さ, 間隔, 最初の待ち, 向き (1 = 自機狙い, 0 = 回転), 速さ, 必要な空き, ずらし表
PatTable:
    dc.w    150, 20, 40, 1, 28, 4
    dc.l    Offs3Way                | 自機狙い 3-way
    dc.w    370, 10, 40, 0, 24, 6
    dc.l    Offs5Wheel              | 5 方向の風車 (回転, 長く)
    dc.w    120, 5, 40, 1, 40, 2
    dc.l    Offs1                   | 自機狙いの直線弾 (連射)
    dc.w    130, 30, 40, 0, 24, 13
    dc.l    Offs12Ring              | 12 方向のリング
    dc.w    150, 24, 40, 1, 26, 6
    dc.l    Offs5Way                | 自機狙い 5-way
    dc.w    370, 8, 40, 0, 26, 4
    dc.l    Offs3Wheel              | 3 方向の風車 (回転, 長く)
    .equ PAT_N, 6

| 向きのずらし (10 度単位), 0x7fff で終わり
Offs1:      dc.w    0, 0x7fff
Offs3Way:   dc.w    -2, 0, 2, 0x7fff
Offs5Way:   dc.w    -4, -2, 0, 2, 4, 0x7fff
Offs3Wheel: dc.w    0, 12, 24, 0x7fff
Offs5Wheel: dc.w    0, 7, 14, 22, 29, 0x7fff
Offs12Ring: dc.w    0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 0x7fff

| 敵・敵弾の処理 (元: 0x0011ac jsr $1000a). 大型ボスの間 ($ff002c != 0) は元の処理が敵弾も止めるので,
| BLACK では敵弾 (移動・表示・当たり判定の表への登録) だけ動かす (大型ボスのリング弾のため).
| 当たり判定の表 ($ff818a, 6 バイト x n, 0xffff で終わり) は大型ボスが毎フレーム作り直すので, その後ろに足す.
BlackEnemySys:
    jsr     0x01000a
    cmpi.w  #RANK_BLACK,RANK
    bne.s   9f
    tst.w   BOSS_MODE
    bne.s   1f
    clr.l   BL_BOSS_OBJ
    bra.s   0f
1:  bsr.w   BossPoolFix
    tst.l   BL_BOSS_OBJ
    beq.s   0f
    bsr.w   BossAttack
0:  tst.w   BIG_BOSS
    beq.s   9f
    lea     HIT_LIST,a1
    move.w  #HIT_LIST_MAX-1,d0
1:  cmpi.w  #0xffff,(a1)
    beq.s   2f
    addq.l  #6,a1
    dbra    d0,1b
    bra.s   9f                      | 終わりが見つからない: 何もしない
2:  move.l  a1,HIT_LIST_PTR
    jsr     0x01189e
9:  rts

| 10 度おきの (cos, sin) x 256
RingTable:
    dc.w    256, 0
    dc.w    252, 44
    dc.w    241, 88
    dc.w    222, 128
    dc.w    196, 165
    dc.w    165, 196
    dc.w    128, 222
    dc.w    88, 241
    dc.w    44, 252
    dc.w    0, 256
    dc.w    -44, 252
    dc.w    -88, 241
    dc.w    -128, 222
    dc.w    -165, 196
    dc.w    -196, 165
    dc.w    -222, 128
    dc.w    -241, 88
    dc.w    -252, 44
    dc.w    -256, 0
    dc.w    -252, -44
    dc.w    -241, -88
    dc.w    -222, -128
    dc.w    -196, -165
    dc.w    -165, -196
    dc.w    -128, -222
    dc.w    -88, -241
    dc.w    -44, -252
    dc.w    0, -256
    dc.w    44, -252
    dc.w    88, -241
    dc.w    128, -222
    dc.w    165, -196
    dc.w    196, -165
    dc.w    222, -128
    dc.w    241, -88
    dc.w    252, -44

| 追加弾: (必要な空き数, cos, sin, cos, -sin) x 角度
SpreadTable:
    dc.w    4, 250, 53, 250, -53    | 約 12 度
    dc.w    6, 234, 104, 234, -104  | 約 24 度
    dc.w    0

| (d6, d7) を (cos, sin) = ((a3)+, (a3)+) で回転して生成. d0/d1/d3/d4 を使う
RotSpawn:
    move.w  (a3)+,d0                | cos
    move.w  (a3)+,d1                | sin
    move.w  d6,d3
    muls.w  d0,d3
    move.w  d7,d4
    muls.w  d1,d4
    sub.l   d4,d3
    asr.l   #8,d3                   | vx' = vx*c - vy*s
    move.w  d6,d4
    muls.w  d1,d4
    move.w  d7,d1
    muls.w  d0,d1
    add.l   d1,d4
    asr.l   #8,d4                   | vy' = vx*s + vy*c
    bra.w   OrigBulletSpawn

| 敵弾プールの空き数 -> d0 (d1 使用)
FreeBulletSlots:
    move.w  BUL_POOL_N,d1
    tst.w   BOSS_MODE
    beq.s   1f
    move.w  BUL_POOL_N_B,d1
1:  moveq   #0,d0
    move.l  d2,-(sp)
    move.l  BUL_MASK,d2
2:  btst    d1,d2
    bne.s   3f
    addq.w  #1,d0
3:  dbra    d1,2b
    move.l  (sp)+,d2
    rts

| ------------------------------------------------------------------
| ザコ敵の耐久力 (元: 0x010390 move.w (a3)+,$24(a2) / move.l (a3)+,$26(a2))
| BLACK: 1.5 倍 (1 以上 0x5000 未満のときだけ)
BlackEnemyHp:
    move.w  d3,-(sp)
    clr.w   OBJ_DUP(a2)
    move.w  (a3)+,d3
    cmpi.w  #RANK_BLACK,RANK
    bne.s   1f
    bsr.s   Hp150
    bsr.w   BlackDupSpawned
1:  move.w  d3,0x24(a2)
    move.l  (a3)+,0x26(a2)
    move.w  (sp)+,d3
    rts

| d3 を 1.5 倍 (1 以上 0x5000 未満のとき)
Hp150:
    cmpi.w  #1,d3
    blt.s   1f
    cmpi.w  #0x5000,d3
    bge.s   1f
    move.w  d3,-(sp)
    lsr.w   #1,d3
    add.w   (sp)+,d3
1:  rts

| ------------------------------------------------------------------
| ボスの耐久力 (元: 0x011e46-0x011e54. Rank 別の 3 値の表から読む)
| BLACK: Hard の値の 1.5 倍 (表は 3 値しか無いので範囲外を読まないように)
BlackBossHp:
    move.w  RANK,d0
    cmpi.w  #RANK_BLACK,d0
    bne.s   1f
    move.w  d3,-(sp)
    move.w  4(a1),d3
    bsr.s   Hp150
    move.w  d3,0x24(a0)
    move.w  (sp)+,d3
    bra.s   2f
1:  add.w   d0,d0
    move.w  (a1,d0.w),0x24(a0)
2:  addq.w  #6,a1
    rts

| ------------------------------------------------------------------
| 当たり判定の表の参照 (元: 0x001fd0 lea $1462(pc),a6 / lsl.w #3,d4 / adda.w d4,a6)
| BLACK: 自機 (種類 1) の当たり判定を小さくする
BlackHitbox:
    lea     HITBOX_TABLE,a6
    cmpi.w  #RANK_BLACK,RANK
    bne.s   1f
    cmpi.w  #1,d4
    bne.s   1f
    lea     BlackPlayerBox,a6
    rts
1:  lsl.w   #3,d4
    adda.w  d4,a6
    rts

| 自機の当たり判定 (元: y 6..9, x 13..28 -> BLACK: y 6..9, x 18..23)
BlackPlayerBox:
    dc.w    6,9,18,23

| ------------------------------------------------------------------
| ザコ敵の移動 (元: 0x0105b8-0x0105cb 位置 += 速度, 継続フレーム -1)
| BLACK: 4 フレームに 1 回もう 1 歩進める (軌道はそのままで約 1.25 倍速).
| 飛行ザコだけ (地上物は BG と同じ速さで動くので速くするとずれる)
BlackEnemyMove:
    move.w  0x14(a0),d4
    add.w   d4,0x1a(a0)
    move.w  0x16(a0),d5
    add.w   d5,0x1c(a0)
    subq.w  #1,0x12(a0)
    cmpi.w  #RANK_BLACK,RANK
    bne.s   9f
    btst    #1,OBJ_DUP+1(a0)        | 飛行ザコの印
    beq.s   9f
    btst    #0,FRAME_CNT+1
    bne.s   9f
    btst    #1,FRAME_CNT+1
    bne.s   9f
    tst.w   0x12(a0)
    beq.s   9f                      | この歩で区切りになるなら追加しない
    add.w   d4,0x1a(a0)
    add.w   d5,0x1c(a0)
    subq.w  #1,0x12(a0)
9:  rts

| ------------------------------------------------------------------
| タイトルで START を選んだとき (元: 0x016e36 move.w #4,$ff5202)
| 試作: C を押しながら START で BLACK LABEL (左+C は元の隠しメニュー)
BlackTitleStart:
    move.w  #4,0xff5202
    move.w  d0,-(sp)
    move.w  PAD_STATE,d0
    andi.w  #0x2400,d0
    cmpi.w  #0x2000,d0
    bne.s   1f
    cmpi.w  #RANK_BLACK,RANK
    beq.s   1f
    move.w  RANK,SAVED_RANK
    move.w  #RANK_BLACK,RANK
1:  move.w  (sp)+,d0
    rts

| ------------------------------------------------------------------
| 隠しメニュー (左+C): 4 行目に BLACK ON/OFF を追加
| (元: START / STAGE / NO DEATH. カーソルの範囲 0x016f48 を 0-3 に)

| 隠しメニューの START (元: 0x016efc move.w #4,$ff5202). BLACK が ON なら BLACK LABEL で始める
BlackDbgStart:
    tst.w   BL_DBG_BLACK
    beq.w   BlackTitleStart         | OFF: 通常の START と同じ (C+START でも BLACK)
    move.w  #4,0xff5202
    cmpi.w  #RANK_BLACK,RANK
    beq.s   1f
    move.w  RANK,SAVED_RANK
    move.w  #RANK_BLACK,RANK
1:  rts

| 隠しメニューでボタン (元: 0x016f40 eori.w #1,$ff4032). d0 = カーソル - 1
BlackDbgToggle:
    cmpi.w  #2,d0
    beq.s   1f
    eori.w  #1,0xff4032             | NO DEATH
    rts
1:  eori.w  #1,BL_DBG_BLACK         | BLACK
    rts

| 隠しメニューの 4 行目を描く (毎フレーム)
BlackDbgDraw:
    lea     DbgBlackLabel,a0
    jsr     DRAW_STRINGS
    lea     DbgBlackOff,a0
    tst.w   BL_DBG_BLACK
    beq.s   1f
    lea     DbgBlackOn,a0
1:  jmp     DRAW_STRINGS

| 文字列 (描画位置, タイル..., 0xffff) ..., 0xffff. タイル 0x630a = A
DbgBlackLabel:
    dc.w    0x09e0, 0x630b, 0x6315, 0x630a, 0x630c, 0x6314, 0, 0, 0, 0, 0xffff, 0xffff
DbgBlackOff:
    dc.w    0x09f2, 0x6318, 0x630f, 0x630f, 0xffff, 0xffff
DbgBlackOn:
    dc.w    0x09f2, 0x6318, 0x6317, 0x0000, 0xffff, 0xffff

| タイトル初期化時: BLACK で遊んだ後なら元の Rank に戻す
BlackRestoreRank:
    clr.w   BL_DBG_BLACK
    cmpi.w  #RANK_BLACK,RANK
    bne.s   1f
    move.w  SAVED_RANK,RANK
    cmpi.w  #2,RANK
    bls.s   1f
    move.w  #1,RANK
1:  rts

| ------------------------------------------------------------------
| ステージ開始時 (元: 0x00457a clr.l $ff7000). BLACK なら敵弾プールを 32 発に広げ,
| スプライト枠を専用の表に移す (元の枠は 0 にしておく)
BlackStageInit:
    clr.l   0xff7000
    cmpi.w  #RANK_BLACK,RANK
    bne.s   9f
    movem.l d0/d7/a0,-(sp)
    movea.l 0xff4c0a,a0
    move.w  BUL_POOL_N,d7
    bsr.w   MoveBulletSat
    move.w  d0,BL_OLDK
    move.l  #BL_BSAT,0xff4c0a
    move.w  #BL_POOL_N,BUL_POOL_N
    lea     BL_QUEUE,a0             | 追加編隊の待ち行列を空に
    moveq   #BL_QUEUE_N-1,d7
1:  clr.l   (a0)+
    dbra    d7,1b
    lea     BL_TCACHE,a0            | 色違いタイルの一覧を空に (面ごとに絵が変わるため)
    moveq   #BL_TCACHE_N*6/4-1,d7
2:  clr.l   (a0)+
    dbra    d7,2b
    move.w  #TILE_A0,BL_TFREE_A
    move.w  #TILE_B0,BL_TFREE_B
    movem.l (sp)+,d0/d7/a0
9:  rts

| ボス戦開始時 (元: 0x011e86 move.w (a1)+,$ff601a). 同上 (ボス戦用の設定)
BlackBossInit:
    move.w  (a1)+,0xff601a
    cmpi.w  #RANK_BLACK,RANK
    bne.s   9f
    move.l  a0,BL_BOSS_OBJ          | ボス (追加の攻撃はここから撃つ)
    movem.l d0/d7/a0,-(sp)
    movea.l 0xff6016,a0
    move.w  BUL_POOL_N_B,d7
    bsr.s   MoveBulletSat
    move.w  d0,BL_OLDK_B
    move.l  #BL_BSAT,0xff6016
    move.w  #BL_POOL_N,BUL_POOL_N_B
    movem.l (sp)+,d0/d7/a0
9:  rts

| a0 = 元の敵弾スプライト枠, d7 = 枠数 - 1. 元の枠と専用の表を 0 にし, 枠の番号 -> d0
MoveBulletSat:
    move.l  a0,d0
    subi.l  #SAT_BUF,d0
    lsr.l   #3,d0
1:  clr.l   (a0)+
    clr.l   (a0)+
    dbra    d7,1b
    lea     BL_BSAT,a0
    moveq   #BL_POOL_N,d7
2:  clr.l   (a0)+
    clr.l   (a0)+
    dbra    d7,2b
    rts

| ------------------------------------------------------------------
| フレームの最後 (元: 0x001128 jsr $326 = VBlank 待ち).
| BLACK のゲーム中は, 元の表と敵弾の表から表示中のスプライトだけを並べた表を作り,
| それを VDP へ送る (80 枠に収める). それ以外は元の表をそのまま送る.
BlackFrameEnd:
    movem.l d0-d2/d7/a0-a1,-(sp)
    cmpi.w  #RANK_BLACK,RANK
    bne.w   8f
    cmpi.w  #3,SCENE
    bne.w   8f
    lea     BL_OSAT,a1
    moveq   #0,d2
    move.w  BL_OLDK,d1
    tst.w   BOSS_MODE
    beq.s   1f
    move.w  BL_OLDK_B,d1
1:  lea     SAT_BUF,a0              | 敵弾より前の枠 (自機など)
    move.w  d1,d7
    bsr.s   CopySat
    | 敵弾: 並び順を毎フレームずらす (横 1 ラインに 20 枚を超えたとき,
    | 消える弾が毎フレーム入れ替わり, 見えなくならずに点滅になる)
    move.w  FRAME_CNT,d0
    mulu    #13,d0
    andi.w  #BL_POOL_N,d0           | 開始位置 r (0-31)
    move.w  d0,-(sp)
    lea     BL_BSAT,a0
    lsl.w   #3,d0
    adda.w  d0,a0
    moveq   #BL_POOL_N+1,d7
    sub.w   (sp),d7                 | r..31
    bsr.s   CopySat
    lea     BL_BSAT,a0
    move.w  (sp)+,d7                | 0..r-1
    bsr.s   CopySat
    move.w  d1,d0                   | 残りの枠 (敵など)
    lsl.w   #3,d0
    lea     SAT_BUF,a0
    adda.w  d0,a0
    moveq   #80,d7
    sub.w   d1,d7
    bsr.s   CopySat
    tst.w   d2
    bne.s   2f
    clr.l   (a1)+                   | 1 枚も無いとき: 見えない 1 枠
    clr.l   (a1)+
2:  clr.b   -5(a1)                  | 最後の枠のリンクを 0 に
    move.l  #0x969a9500,BL_DMASRC   | BL_OSAT (0xff3400) から
    move.w  BL_OSAT,BL_FIRSTW
    bra.s   9f
8:  move.l  #0x96989501,BL_DMASRC   | 元: 0xff3002 から
    move.w  SAT_BUF,BL_FIRSTW
9:  movem.l (sp)+,d0-d2/d7/a0-a1
    jmp     WAIT_VBLANK

| a0 から d7 枠を見て, 表示中 (y か x が 0 以外) の枠を a1 へ詰めて写す. d2 = 写した数
CopySat:
    subq.w  #1,d7
    bmi.s   9f
1:  move.w  (a0),d0
    or.w    6(a0),d0
    beq.s   2f
    cmpi.w  #80,d2
    bcc.s   2f
    move.l  (a0),(a1)+
    move.l  4(a0),(a1)+
    addq.w  #1,d2
    move.b  d2,-5(a1)               | リンク = 次の枠の番号
2:  addq.l  #8,a0
    dbra    d7,1b
9:  rts

| ------------------------------------------------------------------
| 追加編隊 (BLACK): 飛行ザコが出たら, 同じ敵コードを BL_DUP_DELAY フレーム後にもう一度出す.
| 追加で出た敵には印を付け, パレット 2 の部分をパレット 3 で描く (色違いの編隊).

| 敵の出現時 (BlackEnemyHp から). a0 = 出現リストの読み位置 (読んだコードの次), a2 = 敵.
BlackDupSpawned:
    movem.l d0-d1/a1,-(sp)
    move.l  a0,d0
    subi.l  #SPAWN_LIST,d0
    lsr.w   #1,d0                   | 読んだワード数
    cmp.w   BL_ORIG_WORDS,d0
    bls.s   1f
    move.w  #3,OBJ_DUP(a2)          | 追加分として出た敵 (bit 0) で飛行ザコ (bit 1)
    bra.s   9f
1:  move.w  -2(a0),d0               | 敵コード (上位: 出現位置, 下位: 敵の種類)
    bsr.s   IsFlyingZako
    beq.s   9f
    move.w  #2,OBJ_DUP(a2)          | 飛行ザコ (bit 1)
    lea     BL_QUEUE,a1             | 空いている待ち行列に入れる
    moveq   #BL_QUEUE_N-1,d1
2:  tst.w   (a1)
    beq.s   3f
    addq.l  #4,a1
    dbra    d1,2b
    bra.s   9f
3:  move.w  d0,(a1)+
    move.w  #BL_DUP_DELAY,(a1)
9:  movem.l (sp)+,d0-d1/a1
    rts

| d0.b = 敵の種類. 飛行ザコなら Z=0, それ以外 Z=1
IsFlyingZako:
    movem.l d0-d1/a1,-(sp)
    btst    #7,d0
    bne.s   8f                      | 0x80 以上は対象外
    andi.w  #0x7f,d0
    move.w  d0,d1
    lsr.w   #3,d1
    lea     FlyingZako,a1
    move.b  (a1,d1.w),d1
    andi.w  #7,d0
    btst    d0,d1                   | ビットが 0 なら Z=1
    movem.l (sp)+,d0-d1/a1
    rts
8:  ori.b   #0x04,ccr               | Z=1
    movem.l (sp)+,d0-d1/a1
    rts

| 飛行ザコ (耐久力 6 以下, 縦にも動く) の種類のビット表 (種類 0-127)
| 01-0e, 27-2a, 2e, 2f, 31
FlyingZako:
    dc.b    0xfe, 0x7f, 0x00, 0x00, 0x80, 0xc7, 0x02, 0x00
    dc.b    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .even

| 出現リストを作り終えたとき (元: 0x023090-0x0230a3). 待ち時間が来た追加分をリストの後ろに足す.
| d0 = 読み位置, d2 = リストの長さ (バイト)
BlackSpawnInject:
    move.w  d0,0xff9326
    lea     SPAWN_LIST,a1
    cmpi.w  #RANK_BLACK,RANK
    bne.s   9f
    move.w  d2,d0
    lsr.w   #1,d0
    move.w  d0,BL_ORIG_WORDS
    movem.l d1/a2,-(sp)
    lea     BL_QUEUE,a2
    moveq   #BL_QUEUE_N-1,d1
1:  tst.w   (a2)
    beq.s   3f
    subq.w  #1,2(a2)
    bne.s   3f
    cmpi.w  #0x30,d2                | リストの容量を超えない
    bcc.s   3f
    move.w  (a2),(a1,d2.w)
    addq.w  #2,d2
    clr.w   (a2)
3:  addq.l  #4,a2
    dbra    d1,1b
    movem.l (sp)+,d1/a2
9:  move.w  #0,(a1,d2.w)
    rts

| 敵の絵の更新 (元: 0x010540 jsr $1e16). 追加分の敵は色違いのタイル (パレット 3) で描く.
| 色違いタイル: パレット 2 で描く部分をパレット 3 で描き, 緑・黄色になる色 7, 8, 12 を紺 (色 4) にしたコピー.
BlackEnemyAnim:
    jsr     0x001e16
    btst    #0,OBJ_DUP+1(a0)
    beq.s   9f
    movem.l d0-d7/a1-a2,-(sp)
1:  move.w  4(a2),d0
    move.w  d0,d1
    andi.w  #0x6000,d1
    cmpi.w  #0x4000,d1
    bne.s   2f
    move.w  2(a2),d1                | 大きさ -> 枚数 = (w+1)*(h+1)
    move.w  d1,d2
    lsr.w   #8,d1
    andi.w  #3,d1
    addq.w  #1,d1
    lsr.w   #8,d2
    lsr.w   #2,d2
    andi.w  #3,d2
    addq.w  #1,d2
    mulu    d2,d1
    move.w  d0,d2
    andi.w  #0x07ff,d2              | 元のタイル
    bsr.s   GreenTiles              | -> d3 = コピー先 (0 = 用意できない)
    tst.w   d3
    beq.s   2f
    andi.w  #0x9800,d0              | 優先度・反転はそのまま
    ori.w   #0x6000,d0              | パレット 3
    or.w    d3,d0
    move.w  d0,4(a2)
2:  addq.l  #8,a2
    dbra    d7,1b
    movem.l (sp)+,d0-d7/a1-a2
9:  rts

| d2 = 元のタイル, d1 = 枚数 -> d3 = 色違いのコピー先 (一覧に無ければ作る. 0 = 空きなし)
GreenTiles:
    lea     BL_TCACHE,a1
    moveq   #BL_TCACHE_N-1,d4
1:  move.w  (a1),d5
    beq.s   3f                      | 一覧の終わり -> 作る
    cmp.w   d2,d5
    bne.s   2f
    cmp.w   2(a1),d1
    bne.s   2f
    move.w  4(a1),d3
    rts
2:  addq.l  #6,a1
    dbra    d4,1b
    moveq   #0,d3                   | 一覧がいっぱい
    rts
3:  move.w  BL_TFREE_A,d3           | コピー先を探す (A, だめなら B)
    move.w  d3,d5
    add.w   d1,d5
    cmpi.w  #TILE_A1,d5
    bhi.s   4f
    move.w  d5,BL_TFREE_A
    bra.s   5f
4:  move.w  BL_TFREE_B,d3
    move.w  d3,d5
    add.w   d1,d5
    cmpi.w  #TILE_B1,d5
    bhi.s   8f
    move.w  d5,BL_TFREE_B
5:  move.w  d2,(a1)+
    move.w  d1,(a1)+
    move.w  d3,(a1)+
    | 枚数分コピー (VRAM 読み -> 色の置き換え -> 書き込み)
    move.w  d1,d4
    subq.w  #1,d4
    move.w  d2,d5
    move.w  d3,d6
6:  bsr.s   CopyGreenTile
    addq.w  #1,d5
    addq.w  #1,d6
    dbra    d4,6b
    rts
8:  moveq   #0,d3
    rts

| VRAM のタイル d5 を色を置き換えてタイル d6 へ写す (d0/d1/d2/d7/a1 を使う. 呼び出し元で保存済み)
CopyGreenTile:
    movem.l d0-d2/d7/a1,-(sp)
    lea     -32(sp),sp              | 32 バイトの作業領域
    move.w  #0x8f02,VDP_CTRL
    move.w  d5,d0
    bsr.s   VramCmd                 | 読み込みコマンド
    move.l  d0,VDP_CTRL
    movea.l sp,a1
    moveq   #7,d7
1:  move.l  VDP_DATA,(a1)+
    dbra    d7,1b
    movea.l sp,a1
    moveq   #31,d7
2:  move.b  (a1),d0
    move.b  d0,d1
    lsr.b   #4,d0
    andi.w  #0x0f,d0
    andi.w  #0x0f,d1
    move.b  GreenMap(pc,d0.w),d0
    move.b  GreenMap(pc,d1.w),d1
    lsl.b   #4,d0
    or.b    d1,d0
    move.b  d0,(a1)+
    dbra    d7,2b
    move.w  d6,d0
    bsr.s   VramCmd
    ori.l   #0x40000000,d0          | 書き込みコマンド
    move.l  d0,VDP_CTRL
    movea.l sp,a1
    moveq   #7,d7
3:  move.l  (a1)+,VDP_DATA
    dbra    d7,3b
    lea     32(sp),sp
    movem.l (sp)+,d0-d2/d7/a1
    rts

| 色の置き換え表 (パレット 2 の色番号 -> パレット 3 で描く色番号). 7, 8, 12 (緑・黄色になる) -> 4 (紺 0x620)
GreenMap:
    dc.b    0, 1, 2, 3, 4, 5, 6, 4, 4, 9, 10, 11, 4, 13, 14, 15

| d0 = タイル番号 -> d0 = VRAM 読み込みコマンド (アドレス = タイル * 32)
VramCmd:
    andi.l  #0x07ff,d0
    lsl.l   #5,d0
    move.l  d0,d1
    andi.w  #0x3fff,d0
    swap    d0
    clr.w   d0
    lsr.l   #8,d1
    lsr.l   #6,d1                   | アドレス >> 14
    or.w    d1,d0
    rts
