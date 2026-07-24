-- ============================================================
-- 迁移脚本：为 projects 表添加 unit 列
-- 执行方法：登录 Supabase Dashboard → SQL Editor → 粘贴执行
-- ============================================================

-- 1. 添加 unit 列（如果不存在）
ALTER TABLE projects ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT '双';

-- 2. 更新管理员视图函数（加入 unit 字段）
DROP FUNCTION IF EXISTS admin_list_projects();

CREATE OR REPLACE FUNCTION admin_list_projects()
RETURNS TABLE (
    project_id UUID,
    project_name TEXT,
    owner_email TEXT,
    user_id UUID,
    industry TEXT,
    unit TEXT,
    quantity INTEGER,
    price NUMERIC,
    product_cost NUMERIC,
    return_rate NUMERIC,
    ratio NUMERIC,
    platform_fee NUMERIC,
    shipping NUMERIC,
    return_ship NUMERIC,
    daily_orders INTEGER,
    wuyoumai BOOLEAN,
    price_reduction NUMERIC,
    wm_comm NUMERIC,
    funnel_cpc NUMERIC,
    funnel_ctr NUMERIC,
    funnel_consult NUMERIC,
    funnel_convert NUMERIC,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    RETURN QUERY
    SELECT
        p.id::UUID AS project_id,
        p.name::TEXT AS project_name,
        u.email::TEXT AS owner_email,
        p.user_id::UUID,
        p.industry::TEXT,
        p.unit::TEXT,
        p.quantity::INTEGER,
        p.price::NUMERIC,
        p.product_cost::NUMERIC,
        p.return_rate::NUMERIC,
        p.ratio::NUMERIC,
        p.platform_fee::NUMERIC,
        p.shipping::NUMERIC,
        p.return_ship::NUMERIC,
        p.daily_orders::INTEGER,
        p.wuyoumai::BOOLEAN,
        p.price_reduction::NUMERIC,
        p.wm_comm::NUMERIC,
        p.funnel_cpc::NUMERIC,
        p.funnel_ctr::NUMERIC,
        p.funnel_consult::NUMERIC,
        p.funnel_convert::NUMERIC,
        p.created_at::TIMESTAMPTZ
    FROM projects p
    JOIN auth.users u ON p.user_id = u.id
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 刷新 PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- 完成 ✓
