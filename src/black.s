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
    .equ BL_BULLET_SPEED, 179       | 敵弾の速さ (x/256. 179 = 約 0.7 倍)
    .equ BL_POOL_N,       31        | 敵弾プールの数 - 1 (32 発. 使用中ビットが 32 ビットのため上限)

| BLACK 用 RAM (全ステージで未使用を確認した領域)
    .equ BL_POOL,       0xffa400    | 敵弾プール 32 x 0x40 (元: 0xff78ca, 最大 23 発分)
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
    .equ BL_QUEUE,      0xff3720    | 追加編隊の待ち行列: (敵コード.w, 残りフレーム.w) x 16
    .equ BL_QUEUE_N,    16
    .equ SPAWN_LIST,    0xff000a    | このフレームに出す敵コードのリスト (0 で終わり)
    .equ OBJ_DUP,       0x48        | 敵オブジェクト内の未使用欄: 追加編隊の印

| 追加編隊の調整値
    .equ BL_DUP_DELAY,  40          | 元の敵から何フレーム遅れて出すか

| ------------------------------------------------------------------
| 敵弾生成 (元: 0x0117a6). d2 = 弾の種類, d3/d4 = 速度 (1/16 ドット), a0 = 撃った敵.
| 元の処理は a2 (生成した弾) 以外のレジスタを保存する.
| BLACK: 速度を落とし, 角度をずらした弾を最大 4 発追加 (5-way). プールの空きが少ないときは減らす.
BlackBulletSpawn:
    cmpi.w  #RANK_BLACK,RANK
    beq.s   1f
OrigBulletSpawn:
    movem.l d0-d7/a0-a1/a3-a6,-(sp)
    lea     0x00f192,a1
    jmp     BUL_SPAWN_BODY
1:  movem.l d0-d1/d3-d7/a3,-(sp)
    muls.w  #BL_BULLET_SPEED,d3
    asr.l   #8,d3
    muls.w  #BL_BULLET_SPEED,d4
    asr.l   #8,d4
    bsr.s   OrigBulletSpawn         | 本来の弾 (遅くしたもの)
    move.l  a2,-(sp)
    move.w  d3,d6                   | 元の vx
    move.w  d4,d7                   | 元の vy
    lea     SpreadTable,a3
2:  move.w  (a3)+,d5                | 必要な空き数 (0 = 表の終わり)
    beq.s   9f
    bsr.s   FreeBulletSlots
    cmp.w   d5,d0
    blt.s   9f
    bsr.s   RotSpawn                | +角度
    bsr.s   RotSpawn                | -角度
    bra.s   2b
9:  move.l  (sp)+,a2
    movem.l (sp)+,d0-d1/d3-d7/a3
    rts

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
    bra.s   OrigBulletSpawn

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
| BLACK: 4 フレームに 1 回もう 1 歩進める (軌道はそのままで約 1.25 倍速)
BlackEnemyMove:
    move.w  0x14(a0),d4
    add.w   d4,0x1a(a0)
    move.w  0x16(a0),d5
    add.w   d5,0x1c(a0)
    subq.w  #1,0x12(a0)
    cmpi.w  #RANK_BLACK,RANK
    bne.s   9f
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

| タイトル初期化時: BLACK で遊んだ後なら元の Rank に戻す
BlackRestoreRank:
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
    bsr.s   MoveBulletSat
    move.w  d0,BL_OLDK
    move.l  #BL_BSAT,0xff4c0a
    move.w  #BL_POOL_N,BUL_POOL_N
    lea     BL_QUEUE,a0             | 追加編隊の待ち行列を空に
    moveq   #BL_QUEUE_N-1,d7
1:  clr.l   (a0)+
    dbra    d7,1b
    movem.l (sp)+,d0/d7/a0
9:  rts

| ボス戦開始時 (元: 0x011e86 move.w (a1)+,$ff601a). 同上 (ボス戦用の設定)
BlackBossInit:
    move.w  (a1)+,0xff601a
    cmpi.w  #RANK_BLACK,RANK
    bne.s   9f
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
    move.w  #1,OBJ_DUP(a2)          | 追加分として出た敵
    bra.s   9f
1:  move.w  -2(a0),d0               | 敵コード (上位: 出現位置, 下位: 敵の種類)
    bsr.s   IsFlyingZako
    beq.s   9f
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

| 敵の絵の更新 (元: 0x010540 jsr $1e16). 追加分の敵はパレット 2 -> 3 に
BlackEnemyAnim:
    jsr     0x001e16
    tst.w   OBJ_DUP(a0)
    beq.s   9f
    movem.l d0/d7/a2,-(sp)
1:  move.w  4(a2),d0
    andi.w  #0x6000,d0
    cmpi.w  #0x4000,d0
    bne.s   2f
    ori.w   #0x2000,4(a2)
2:  addq.l  #8,a2
    dbra    d7,1b
    movem.l (sp)+,d0/d7/a2
9:  rts
