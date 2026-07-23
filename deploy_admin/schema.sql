-- ============================================================
-- 闲鱼商业决策系统 - Supabase 数据库 Schema
-- 使用方法：登录 Supabase Dashboard → SQL Editor → 粘贴执行
-- ============================================================

-- ========== 1. projects 表：经营项目 ==========
CREATE TABLE IF NOT EXISTS projects (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name        TEXT NOT NULL DEFAULT '我的项目',
    industry    TEXT DEFAULT 'shoes',  -- shoes / ceramic / digital / clothing / custom
    
    -- 基础参数快照
    quantity      INTEGER  DEFAULT 1000,
    price         NUMERIC DEFAULT 99,
    product_cost  NUMERIC DEFAULT 35,
    return_rate   NUMERIC DEFAULT 15,
    ratio         NUMERIC DEFAULT 2,
    platform_fee  NUMERIC DEFAULT 1.6,
    shipping      NUMERIC DEFAULT 5,
    return_ship   NUMERIC DEFAULT 3,
    daily_orders  INTEGER  DEFAULT 20,
    
    -- 无忧卖配置
    wuyoumai        BOOLEAN DEFAULT false,
    price_reduction NUMERIC DEFAULT 5,
    wm_comm         NUMERIC DEFAULT 6,
    
    -- 漏斗系数
    funnel_cpc      NUMERIC DEFAULT 3.7,
    funnel_ctr      NUMERIC DEFAULT 3,
    funnel_consult  NUMERIC DEFAULT 20,
    funnel_convert  NUMERIC DEFAULT 30,
    
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

-- ========== 2. daily_data 表：每日投放数据 ==========
CREATE TABLE IF NOT EXISTS daily_data (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    project_id   UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
    user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date         DATE NOT NULL,
    spend        NUMERIC DEFAULT 0,
    impressions  INTEGER DEFAULT 0,
    clicks       INTEGER DEFAULT 0,
    consult      INTEGER DEFAULT 0,
    orders       INTEGER DEFAULT 0,
    returns      INTEGER DEFAULT 0,
    created_at   TIMESTAMPTZ DEFAULT now(),
    UNIQUE(project_id, date)
);

-- ========== 3. 索引 ==========
CREATE INDEX IF NOT EXISTS idx_projects_user   ON projects(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_project    ON daily_data(project_id);
CREATE INDEX IF NOT EXISTS idx_daily_user_date  ON daily_data(user_id, date);

-- ========== 4. updated_at 自动更新触发器 ==========
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_projects_updated ON projects;
CREATE TRIGGER trg_projects_updated BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ========== 5. RLS 行级安全策略 ==========
-- 核心安全机制：用户只能访问自己的数据

-- projects 表
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "用户可以查看自己的项目" ON projects
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "用户可以创建项目" ON projects
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户可以更新自己的项目" ON projects
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "用户可以删除自己的项目" ON projects
    FOR DELETE USING (auth.uid() = user_id);

-- daily_data 表
ALTER TABLE daily_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "用户可以查看自己的每日数据" ON daily_data
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "用户可以创建每日数据" ON daily_data
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户可以更新自己的每日数据" ON daily_data
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "用户可以删除自己的每日数据" ON daily_data
    FOR DELETE USING (auth.uid() = user_id);

-- ========== 6. 视图：每日数据汇总（方便查询） ==========
CREATE OR REPLACE VIEW v_daily_summary AS
SELECT
    project_id,
    COUNT(*) AS days,
    SUM(spend) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(consult) AS total_consult,
    SUM(orders) AS total_orders,
    SUM(returns) AS total_returns,
    CASE WHEN SUM(clicks) > 0 THEN SUM(spend) / SUM(clicks) ELSE 0 END AS avg_cpc,
    CASE WHEN SUM(impressions) > 0 THEN SUM(clicks)::FLOAT / SUM(impressions) ELSE 0 END AS avg_ctr,
    CASE WHEN SUM(clicks) > 0 THEN SUM(consult)::FLOAT / SUM(clicks) ELSE 0 END AS avg_consult_rate,
    CASE WHEN SUM(consult) > 0 THEN SUM(orders)::FLOAT / SUM(consult) ELSE 0 END AS avg_convert_rate,
    CASE WHEN SUM(orders) > 0 THEN SUM(returns)::FLOAT / SUM(orders) ELSE 0 END AS avg_return_rate
FROM daily_data
GROUP BY project_id;

-- ========== 7. 管理员视图（仅管理员可调用） ==========
-- 核心逻辑：使用 SECURITY DEFINER 绕过 RLS，函数内部检查调用者身份

-- 管理员邮箱常量（修改此处可更换管理员）
CREATE OR REPLACE FUNCTION admin_email()
RETURNS TEXT AS $$
BEGIN
    RETURN 'ahhsxycb@163.com';
END;
$$ LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER;

-- 检查当前调用者是否为管理员
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
DECLARE
    current_user_email TEXT;
BEGIN
    SELECT email INTO current_user_email
    FROM auth.users
    WHERE id = auth.uid();
    RETURN current_user_email = admin_email();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 管理员：查看所有注册用户
CREATE OR REPLACE FUNCTION admin_list_users()
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    created_at TIMESTAMPTZ,
    last_sign_in_at TIMESTAMPTZ
) AS $$
BEGIN
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    RETURN QUERY
    SELECT id, email, created_at, last_sign_in_at
    FROM auth.users
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 管理员：查看所有项目
CREATE OR REPLACE FUNCTION admin_list_projects()
RETURNS TABLE (
    project_id UUID,
    project_name TEXT,
    owner_email TEXT,
    industry TEXT,
    quantity INTEGER,
    price NUMERIC,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    RETURN QUERY
    SELECT
        p.id,
        p.name,
        u.email,
        p.industry,
        p.quantity,
        p.price,
        p.created_at
    FROM projects p
    JOIN auth.users u ON p.user_id = u.id
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 管理员：查看所有每日数据
CREATE OR REPLACE FUNCTION admin_list_daily_data()
RETURNS TABLE (
    data_id UUID,
    project_id UUID,
    project_name TEXT,
    owner_email TEXT,
    data_date DATE,
    spend NUMERIC,
    impressions INTEGER,
    clicks INTEGER,
    consult INTEGER,
    orders INTEGER,
    returns INTEGER
) AS $$
BEGIN
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    RETURN QUERY
    SELECT
        d.id,
        d.project_id,
        p.name,
        u.email,
        d.date,
        d.spend,
        d.impressions,
        d.clicks,
        d.consult,
        d.orders,
        d.returns
    FROM daily_data d
    JOIN projects p ON d.project_id = p.id
    JOIN auth.users u ON d.user_id = u.id
    ORDER BY d.date DESC, u.email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 刷新 PostgREST schema cache，让 RPC 函数立即可调用
NOTIFY pgrst, 'reload schema';

-- 完成 ==========
-- 执行完毕后：
-- 1. 到 Authentication → Settings 开启邮箱登录（或手机号）
-- 2. 到 Settings → API 获取 Project URL 和 anon key
-- 3. 填入 HTML 文件的 Supabase 配置面板
