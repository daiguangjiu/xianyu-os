-- ========== 管理员函数修复脚本（v3 · 显式类型转换） ==========
-- 适用场景：admin.html 加载报错
--   "Could not find the function public.admin_email without parameters in the schema cache"
--   "structure of query does not match function result type"
--   或 admin_list_projects 返回字段不全
--
-- 使用方法：
--   1. 登录 Supabase Dashboard
--   2. 左侧菜单 → SQL Editor → New Query
--   3. 粘贴本文件全部内容 → Run
--   4. 等待 10-30 秒（PostgREST 刷新 schema cache）
--   5. 回到管理后台点「刷新全部数据」重新加载

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

-- ⚠ 先删除旧版函数（返回类型变更时 CREATE OR REPLACE 会报 42P13 错误，必须先 DROP）
DROP FUNCTION IF EXISTS admin_list_users();
DROP FUNCTION IF EXISTS admin_list_projects();
DROP FUNCTION IF EXISTS admin_list_daily_data();

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
    SELECT u.id::UUID, u.email::TEXT, u.created_at::TIMESTAMPTZ, u.last_sign_in_at::TIMESTAMPTZ
    FROM auth.users u
    ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 管理员：查看所有项目（含完整参数，供管理后台展示）
CREATE OR REPLACE FUNCTION admin_list_projects()
RETURNS TABLE (
    project_id UUID,
    project_name TEXT,
    owner_email TEXT,
    user_id UUID,
    industry TEXT,
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

-- 管理员：查看所有每日数据（含 user_id，供管理后台按用户筛选）
CREATE OR REPLACE FUNCTION admin_list_daily_data()
RETURNS TABLE (
    data_id UUID,
    project_id UUID,
    project_name TEXT,
    owner_email TEXT,
    user_id UUID,
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
        d.id::UUID AS data_id,
        d.project_id::UUID,
        p.name::TEXT AS project_name,
        u.email::TEXT AS owner_email,
        d.user_id::UUID,
        d.date::DATE AS data_date,
        d.spend::NUMERIC,
        d.impressions::INTEGER,
        d.clicks::INTEGER,
        d.consult::INTEGER,
        d.orders::INTEGER,
        d.returns::INTEGER
    FROM daily_data d
    JOIN projects p ON d.project_id = p.id
    JOIN auth.users u ON d.user_id = u.id
    ORDER BY d.date DESC, u.email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 刷新 PostgREST schema cache（关键！让函数立即可用）
NOTIFY pgrst, 'reload schema';
