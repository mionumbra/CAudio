/* began */

/// @desc 这个函数会尝试把一个给定的值转换为有符号 32 位整数
/// @param {Real} value 要尝试转换的数值
/// @return {Real}
function uint32(_v) {
    // 生成 int32 的唯一方式是通过缓冲区读取
    var _buff = (buffer_create(16, buffer_fixed, 1));
    buffer_write(_buff, buffer_u32, _v);
    var _ui32 = (buffer_peek(_buff, 0, buffer_u32));
    buffer_delete(_buff);
    return(_ui32);
};

/* ended */