-- ══════════════════════════════════════════════════════════════
--  云境旅游 · 全站数据库结构
--  Platform: Supabase (PostgreSQL)
--  Version:  1.0
--  Run this entire file in Supabase → SQL Editor
-- ══════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────
-- 0. 扩展（Supabase 默认已开启，保险起见显式声明）
-- ──────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";


-- ══════════════════════════════════════════════════════════════
-- 1. destinations  —  目的地
--    对应前台：首页"世界等着你去发现"板块
-- ══════════════════════════════════════════════════════════════
create table if not exists destinations (
  id           uuid        primary key default gen_random_uuid(),

  -- 基本信息
  name         text        not null,               -- 目的地名称，如"云南·香格里拉"
  country      text        not null,               -- 国家/地区，如"中国 · China"
  description  text,                               -- 简介（显示在卡片上）
  long_desc    text,                               -- 详细介绍（详情页备用）

  -- 视觉
  cover_url    text,                               -- 封面图 URL
  icon_emoji   text        default '🌍',           -- 装饰性 emoji
  gradient     text,                               -- 自定义 CSS 渐变（无图时用）

  -- 分类标签
  tag          text        default '自然秘境',      -- 卡片标签，如"海岛天堂"
  region       text        default 'asia',          -- 地区：asia / europe / africa / oceania / americas / polar

  -- 展示控制
  sort_order   int         default 0,              -- 排序权重（越小越靠前）
  is_featured  boolean     default false,           -- 是否首页重点展示（大卡片）
  status       text        default 'published',     -- published / draft / hidden

  -- 时间戳
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

comment on table destinations is '目的地 — 对应官网"精选目的地"板块';
comment on column destinations.is_featured is '为 true 时在首页占大卡片位置';


-- ══════════════════════════════════════════════════════════════
-- 2. packages  —  旅游线路 / 套餐
--    对应前台："精选线路"板块
-- ══════════════════════════════════════════════════════════════
create table if not exists packages (
  id              uuid        primary key default gen_random_uuid(),

  -- 关联目的地（可空，一个套餐对应一个主目的地）
  destination_id  uuid        references destinations(id) on delete set null,

  -- 基本信息
  title           text        not null,             -- 线路名称
  subtitle        text,                             -- 副标题/卖点
  description     text,                             -- 简介（卡片展示）
  itinerary       text,                             -- 详细行程（富文本/Markdown）

  -- 规格
  duration_days   int         not null default 7,   -- 天数
  duration_nights int,                              -- 夜数（默认 days-1）
  min_people      int         default 1,
  max_people      int         default 20,

  -- 价格
  price           numeric(10,2) not null,           -- 起步价（元/人）
  price_note      text        default '/人',        -- 价格备注
  original_price  numeric(10,2),                    -- 划线原价（可空）

  -- 标签与包含内容
  tags            text[]      default '{}',         -- 如 ["小团精品","含早餐","含接送"]
  includes        text[]      default '{}',         -- 含：机票/酒店/导游
  excludes        text[]      default '{}',         -- 不含：个人消费/签证

  -- 视觉
  cover_url       text,
  icon_emoji      text        default '✈️',
  gradient        text,                             -- 无图时的渐变色

  -- 标记
  badge           text,                             -- 如"爆款" / "新上线" / "精选"
  badge_type      text        default 'hot',        -- hot / new / top
  is_featured     boolean     default false,

  -- 状态
  status          text        default 'published',  -- published / draft / archived
  sort_order      int         default 0,

  -- 时间戳
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

comment on table packages is '旅游线路/套餐 — 对应官网"精选线路"板块';


-- ══════════════════════════════════════════════════════════════
-- 3. services  —  服务项目
--    对应前台："全程无忧，交给我们"板块
-- ══════════════════════════════════════════════════════════════
create table if not exists services (
  id           uuid        primary key default gen_random_uuid(),

  -- 基本信息
  title        text        not null,               -- 服务名称，如"深度定制行程"
  description  text,                               -- 描述（卡片展示）
  detail       text,                               -- 详细说明（详情页备用）

  -- 视觉
  icon_emoji   text        default '⭐',           -- 服务图标 emoji
  cover_url    text,

  -- 展示控制
  sort_order   int         default 0,
  status       text        default 'published',    -- published / hidden

  -- 时间戳
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

comment on table services is '服务项目 — 对应官网"我们的服务"板块';


-- ══════════════════════════════════════════════════════════════
-- 4. reviews  —  旅客评价
--    对应前台："他们走过，这样说"板块
-- ══════════════════════════════════════════════════════════════
create table if not exists reviews (
  id              uuid        primary key default gen_random_uuid(),

  -- 关联（可选：关联到具体线路）
  package_id      uuid        references packages(id) on delete set null,

  -- 评价人信息
  author_name     text        not null,            -- 旅客姓名
  author_location text,                            -- 来自哪里，如"上海"
  avatar_url      text,                            -- 头像图片 URL
  avatar_color    text        default '#667eea',   -- 无头像时的背景色
  avatar_initial  text,                            -- 无头像时显示的文字（通常取姓）

  -- 评价内容
  content         text        not null,            -- 评价正文
  trip_name       text,                            -- 出行的线路名，如"云南深度7日游"
  trip_date       date,                            -- 出行时间

  -- 评分
  rating          smallint    default 5 check (rating between 1 and 5),

  -- 展示控制
  is_featured     boolean     default false,        -- 首页重点展示
  sort_order      int         default 0,
  status          text        default 'published',  -- published / hidden / pending

  -- 时间戳
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

comment on table reviews is '旅客评价 — 对应官网"旅客好评"板块';


-- ══════════════════════════════════════════════════════════════
-- 5. inquiries  —  在线询价 / 咨询表单
--    对应前台："联系我们"表单提交
-- ══════════════════════════════════════════════════════════════
create table if not exists inquiries (
  id               uuid        primary key default gen_random_uuid(),

  -- 关联（可选）
  package_id       uuid        references packages(id) on delete set null,
  destination_id   uuid        references destinations(id) on delete set null,

  -- 客户信息
  name             text        not null,            -- 姓名
  phone            text,                            -- 联系电话
  email            text,                            -- 邮箱
  wechat           text,                            -- 微信号

  -- 需求信息
  interest         text,                            -- 感兴趣的目的地/线路
  depart_date      text,                            -- 出发时间（月份字符串）
  people_count     text,                            -- 出行人数描述
  budget           text,                            -- 预算范围
  message          text,                            -- 留言/特殊需求

  -- 处理状态
  status           text        default 'new',       -- new / contacted / closed / spam
  replied_at       timestamptz,                     -- 回复时间
  staff_note       text,                            -- 内部备注（不对外展示）

  -- 来源追踪
  source           text        default 'website',   -- website / wechat / phone / referral
  utm_source       text,
  utm_medium       text,

  -- 时间戳
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

comment on table inquiries is '在线询价 — 对应官网"联系我们"表单';


-- ══════════════════════════════════════════════════════════════
-- 6. banners  —  首页轮播 / 宣传 Banner
--    对应前台：Hero 区或促销 Banner 区
-- ══════════════════════════════════════════════════════════════
create table if not exists banners (
  id           uuid        primary key default gen_random_uuid(),

  -- 内容
  title        text        not null,               -- 主标题
  subtitle     text,                               -- 副标题
  badge_text   text,                               -- 顶部小徽标文字，如"年度最佳旅行品牌"
  cta_text     text        default '立即探索',     -- 按钮文字
  cta_url      text,                               -- 按钮跳转链接（可为锚点）
  cta2_text    text,                               -- 第二按钮文字（可空）
  cta2_url     text,

  -- 视觉
  cover_url    text,                               -- 背景图 URL
  gradient     text,                               -- 背景渐变（无图时）

  -- 展示控制
  position     text        default 'hero',         -- hero / promo / popup
  sort_order   int         default 0,
  status       text        default 'published',    -- published / draft

  -- 有效期（可空表示永久有效）
  starts_at    timestamptz,
  ends_at      timestamptz,

  -- 时间戳
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

comment on table banners is 'Banner — 对应官网 Hero 区和促销横幅';


-- ══════════════════════════════════════════════════════════════
-- Row Level Security（开发阶段全开放；上线前按需收紧）
-- ══════════════════════════════════════════════════════════════
alter table destinations  enable row level security;
alter table packages      enable row level security;
alter table services      enable row level security;
alter table reviews       enable row level security;
alter table inquiries     enable row level security;
alter table banners       enable row level security;

-- 前台：只读已发布内容
create policy "public_read_destinations" on destinations  for select using (status = 'published');
create policy "public_read_packages"     on packages      for select using (status = 'published');
create policy "public_read_services"     on services      for select using (status = 'published');
create policy "public_read_reviews"      on reviews       for select using (status = 'published');
create policy "public_read_banners"      on banners       for select using (status = 'published');

-- 前台：允许游客提交询价（insert only，不可读取他人记录）
create policy "public_insert_inquiries"  on inquiries     for insert with check (true);

-- 管理后台：全表操作（此处用 anon key + allow all，正式上线应换 service_role 或 auth）
create policy "admin_all_destinations"  on destinations  for all using (true) with check (true);
create policy "admin_all_packages"      on packages      for all using (true) with check (true);
create policy "admin_all_services"      on services      for all using (true) with check (true);
create policy "admin_all_reviews"       on reviews       for all using (true) with check (true);
create policy "admin_all_inquiries"     on inquiries     for all using (true) with check (true);
create policy "admin_all_banners"       on banners       for all using (true) with check (true);


-- ══════════════════════════════════════════════════════════════
-- 索引（提升后台查询性能）
-- ══════════════════════════════════════════════════════════════
create index if not exists idx_destinations_status     on destinations (status, sort_order);
create index if not exists idx_packages_status         on packages     (status, sort_order);
create index if not exists idx_packages_destination    on packages     (destination_id);
create index if not exists idx_reviews_status          on reviews      (status, is_featured);
create index if not exists idx_reviews_package         on reviews      (package_id);
create index if not exists idx_inquiries_status        on inquiries    (status, created_at desc);
create index if not exists idx_banners_position        on banners      (position, status, sort_order);


-- ══════════════════════════════════════════════════════════════
-- 触发器：自动更新 updated_at
-- ══════════════════════════════════════════════════════════════
create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_destinations_updated  before update on destinations  for each row execute function touch_updated_at();
create trigger trg_packages_updated      before update on packages      for each row execute function touch_updated_at();
create trigger trg_services_updated      before update on services      for each row execute function touch_updated_at();
create trigger trg_reviews_updated       before update on reviews       for each row execute function touch_updated_at();
create trigger trg_inquiries_updated     before update on inquiries     for each row execute function touch_updated_at();
create trigger trg_banners_updated       before update on banners       for each row execute function touch_updated_at();


-- ══════════════════════════════════════════════════════════════
-- 示例种子数据（可选运行）
-- ══════════════════════════════════════════════════════════════

-- 目的地
insert into destinations (name, country, description, tag, region, sort_order, is_featured, icon_emoji, gradient) values
('云南·香格里拉',   '中国 · China',      '雪山、草甸、藏寨，高原上最接近天堂的地方', '自然秘境', 'asia',    0, true,  '🌿', 'linear-gradient(160deg,#1a3a2a,#2d6a4f,#52b788,#b7e4c7)'),
('马尔代夫',        '马尔代夫 · Maldives','碧海蓝天，水上屋别墅，蜜月首选',           '海岛天堂', 'asia',    1, false, '🌊', 'linear-gradient(160deg,#0a1628,#1a3a5c,#2196a0,#64c8d4)'),
('摩洛哥·撒哈拉',  '摩洛哥 · Morocco',   '漫漫黄沙，驼铃声声，最浪漫的沙漠之旅',     '异域探险', 'africa',  2, false, '🏜', 'linear-gradient(160deg,#1a0a00,#8b4513,#cd853f,#f4a460)'),
('冰岛·极光之旅',  '冰岛 · Iceland',     '北极圈下的奇幻光影，此生必看的天象',       '极地探索', 'polar',   3, false, '🏔', 'linear-gradient(160deg,#0d0d2b,#1a1a6e,#6060d0,#c8a0f0)');

-- 线路套餐
insert into packages (title, description, duration_days, duration_nights, price, badge, badge_type, tags, icon_emoji, gradient, sort_order, is_featured) values
('云南深度探秘之旅',   '丽江古城、玉龙雪山、泸沽湖、香格里拉，一次走遍云南精华。专属导游，小团出行。', 7, 6, 3980,  '爆款', 'hot', '{"小团精品","含早餐","含接送","摄影指导"}', '🏔', 'linear-gradient(135deg,#0f2d1f,#2d6a4f,#52b788)', 0, true),
('马尔代夫蜜月专属套餐','水上别墅、私人海滩、烛光晚餐、潜水浮潜，为你的爱情打造最完美的注脚。',         5, 4, 12800, '精选', 'top', '{"水上别墅","蜜月专属","含全餐","机票含税"}', '🌊', 'linear-gradient(135deg,#0d1b2a,#1a3a5c,#2196a0)', 1, true),
('冰岛极光深度游',     '雷克雅未克、黄金圈、杰古沙龙冰河湖，赶上极光季，亲眼目睹这场大自然的灯光秀。', 10, 9, 21500, '新上线','new', '{"极光保障","小团定制","含签证","摄影师随行"}', '🌌', 'linear-gradient(135deg,#0d0d2b,#1a1a6e,#6060d0)', 2, true);

-- 服务项目
insert into services (title, description, icon_emoji, sort_order) values
('深度定制行程', '专属顾问一对一沟通，根据你的时间、预算、偏好，量身打造独一无二的旅行方案。', '🗺', 0),
('机票·签证代办', '全球机票比价、签证材料准备、行前攻略，让你出发前就万事俱备。',               '✈️', 1),
('精品酒店甄选', '深度评测百余家精品酒店，从奢华度假村到特色民宿，只选最适合你的那一家。',   '🏨', 2),
('全程安全保障', '旅行保险、24小时紧急联络、应急预案，让你和家人放心出发，平安归来。',       '🔒', 3),
('旅行摄影服务', '专业摄影师随行，在最美的光线下，定格你最真实的旅途瞬间。',               '📸', 4),
('本地向导带队', '精通当地文化与语言的本地向导，带你走进游客踩不到的秘境。',               '🌐', 5),
('美食体验规划', '从当地街头小吃到米其林餐厅，我们帮你找到最值得一吃的每一口。',           '🍽', 6),
('行后服务跟进', '旅途结束不是终点。我们整理行程照片、收集反馈，为下一次出发做好准备。',   '🎒', 7);

-- 旅客评价
insert into reviews (author_name, author_location, avatar_initial, avatar_color, content, trip_name, rating, is_featured, sort_order) values
('林晓婷', '上海', '林', '#667eea', '云南那趟旅行是我这几年最难忘的经历。导游特别专业，行程安排得很舒服，不赶不拖，每一个景点都有足够的时间好好感受。强烈推荐！', '云南深度7日游',    5, true, 0),
('陈建国', '深圳', '陈', '#f5576c', '结婚5周年纪念日，选了马尔代夫蜜月套餐。水上屋的日落我永远忘不了，感谢云境帮我们安排了那顿惊喜烛光晚餐，老婆感动哭了。',   '马尔代夫蜜月5日', 5, true, 1),
('张雨欣', '北京', '张', '#00f2fe', '冰岛极光之旅超出预期！极光保障承诺是真实的，第三天晚上我们真的看到了满天绿光。随行摄影师帮我拍的照片已经冲印挂在客厅了。', '冰岛极光10日游',  5, true, 2);

-- Banner
insert into banners (title, subtitle, badge_text, cta_text, cta_url, cta2_text, cta2_url, position, gradient) values
('让每一次出发都成为传奇', '云境旅游，专注高品质定制旅行。从云南秘境到欧洲古城，我们为你的每一程旅途，注入独一无二的温度与深度。', '2025 年度最佳旅行品牌', '探索线路', '#packages', '查看目的地', '#destinations', 'hero',  'linear-gradient(135deg,#0d1b2a,#1a2f4a,#0f2d1f)'),
('你的下一段旅程，从这里开始', '限时优惠：2025年出发，立减 ¥500。名额有限，先到先得。', null, '免费获取行程方案', '#contact', null, null, 'promo', 'linear-gradient(135deg,#c9a84c,#8b6914,#c9a84c)');
