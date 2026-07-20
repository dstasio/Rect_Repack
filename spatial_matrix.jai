Spatial_Matrix :: struct (Key_Type: Type, Value_Type: Type, Uninitialized_Value: Value_Type = 0, Key_Tolerance: Key_Type = 0) {
    /**
     *  Linear array representing a matrix of values.
     *  The values are arranged in row-major order:
     *
     *             0 1 2 ...
     *          0  A B C             (row, col) -> _valueMatrix[row * colCount + col]
     *          1  D E F
     *          2  G H I
     *          .
     *          .
     */
    values : [..]Value_Type;
    rows   : [..]Key_Type;
    columns: [..]Key_Type;
}

add_at :: (using matrix: *Spatial_Matrix, row: matrix.Key_Type, column: matrix.Key_Type, value: matrix.Value_Type, allow_replacing := true) {
    assert(value != Uninitialized_Value);

    // If this is the first element of the matrix, we can directly add it and return immediately.
    if (rows.count == 0 && columns.count == 0) {
        array_add(*rows, row);
        array_add(*columns, column);
        array_add(*values, value);
        return;
    }

    find_equal_or_first_greater_than :: (container: []Key_Type, key: Key_Type) -> index: int, exact_match: bool {
        for container {
            if it >= (key - Key_Tolerance) && it <= (key + Key_Tolerance) then return it_index, true;
            if it >  (key + Key_Tolerance) return it_index, false;
        }
        return container.count, false;
    }

    row_index, row_exists := find_equal_or_first_greater_than(rows, row);
    col_index, col_exists := find_equal_or_first_greater_than(columns, column);

    if !allow_replacing && row_exists && col_exists && get_at_index(matrix, row_index, col_index) != Uninitialized_Value {
        //log_error("[Spatial_Matrix/%] Trying to replace an existing value into a spatial matrix", #procedure_name());
        return;
    }

    // If the row value is not already present in the matrix, we add a row.
    if !row_exists {
        array_insert_at(*rows, row, row_index);

        // Add an uninitialized value for each column that intersects this new row.
        slots_to_insert := columns.count;
        array_resize(*values, values.count + slots_to_insert, initialize = false);

        move_rows(matrix, row_index + 1, row_index, rows.count - row_index);

        //for 0..columns.count-1
            //values[columns.count * row_index + it] = Uninitialized_Value;
    }

    // If the column value is not already present in the matrix, we add a column.
    if !col_exists {
        slots_to_insert := rows.count;
        array_resize(*values, values.count + slots_to_insert, initialize = false);

        move_columns(matrix, col_index + 1, col_index);

        array_insert_at(*columns, column, col_index);
    }

    values[row_index * columns.count + col_index] = value;
}

remove_at :: (using matrix: *Spatial_Matrix, row: matrix.Key_Type, column: matrix.Key_Type) {
    row_index := find_index(rows, row, Key_Tolerance);
    col_index := find_index(columns, column, Key_Tolerance);
    if row_index == -1 || col_index == -1 {
        log_error("[Spatial_Matrix/%] Tried to remove at (%, %), but that slot does not exist.\n", #procedure_name(), column, row);
        return;
    }

    values[row_index * columns.count + col_index] = Uninitialized_Value;

    row_empty := true;
    row_start_index := row_index * columns.count;
    row_end_index   := row_start_index + columns.count - 1;
    for index: row_start_index .. row_end_index {
        if values[index] == Uninitialized_Value continue;
        row_empty = false;
        break;
    }

    // If the row is empty, we can remove it from the matrix.
    if row_empty {
        is_last_row := row_index == rows.count;

        if !is_last_row
            move_rows(matrix, row_index, row_index + 1, rows.count - row_index - 1);
        array_resize(*values, values.count - columns.count);

        array_ordered_remove_by_index(*rows, row_index);
    }

    col_empty := true;
    {
        index := col_index;
        while index < values.count {
            defer index += columns.count;
            if values[index] == Uninitialized_Value continue;
            col_empty = false;
            break;
        }
    }

    // If the column is empty, we can remove it from the matrix.
    if col_empty {
        move_columns(matrix, col_index, col_index + 1);
        array_resize(*values, values.count - rows.count);

        array_ordered_remove_by_index(*columns, col_index);
    }
}

operator [] :: (using matrix: Spatial_Matrix, row_index: int) -> []matrix.Value_Type {
    assert(row_index >= 0 && row_index < rows.count, "Index out of range (%, %): %", 0, rows.count-1, row_index);

    row : []Value_Type;
    row.count = columns.count;
    row.data  = *values.data[columns.count * row_index];

    return row;
}

get_at :: (using matrix: Spatial_Matrix, row: matrix.Key_Type, column: matrix.Key_Type) -> matrix.Value_Type {
    row_index := find_index(rows, row, Key_Tolerance);
    col_index := find_index(columns, column, Key_Tolerance);
    if row_index < 0 || col_index < 0 {
        return Uninitialized_Value;
    }

    return get_at_index(matrix, row_index, col_index);
}

// @todo: Maybe this should return a pointer?
get_at_index :: (using matrix: Spatial_Matrix, row_index: int, column_index: int) -> matrix.Value_Type {
    if  row_index    < 0 || row_index    >= rows   .count ||
        column_index < 0 || column_index >= columns.count {
        // Should we log an error/warning?
        return Uninitialized_Value;
    }

    value := values[row_index * columns.count + column_index];
    return value;
}

reserve :: (using matrix: *Spatial_Matrix, row_reserve: int, col_reserve: int) {
    array_reserve(*rows,    row_reserve);
    array_reserve(*columns, col_reserve);
    array_reserve(*values,  row_reserve * col_reserve);
}

#scope_file
Memory :: #import "Memory";

find_index :: (container: []$T, key: T, $Key_Tolerance: T) -> index: int {
    for container
        if it >= (key - Key_Tolerance) && it <= (key + Key_Tolerance) then return it_index;
    return -1;
}

move_rows :: (using matrix: Spatial_Matrix, destination_row: int, source_row: int, row_count: int) {
    if destination_row == source_row return;

    linear_destination_index := columns.count * destination_row;
    linear_source_index      := columns.count * source_row;
    byte_count               := columns.count * row_count * size_of(Value_Type);

    destination_pointer := values.data + linear_destination_index;
    source_pointer      := values.data + linear_source_index;

    Memory.copy(destination_pointer, source_pointer, byte_count);

    if destination_row > source_row && source_row != 0 {
        row_before_source_pointer := source_pointer - columns.count;
        new_rows := destination_row - source_row;
        for 0..new_rows-1 {
            Memory.copy(source_pointer + columns.count * it, row_before_source_pointer, columns.count * size_of(Value_Type));
        }
    }
}

move_columns :: (using matrix: Spatial_Matrix, destination_col: int, source_col: int) {
    if destination_col == source_col return;

    if destination_col < source_col {
        // We are removing one or more columns.

        columns_to_delete := source_col - destination_col;
        slots_to_delete   := columns_to_delete * rows.count;

        first_index_to_update := destination_col; // first row + destination column index
        next_index_to_skip    := destination_col; // first row + destination column index
        last_index_to_update  := values.count - slots_to_delete - 1;
        copy_index            := first_index_to_update;

        it := first_index_to_update;
        while it <= last_index_to_update {
            if it == next_index_to_skip {
                next_index_to_skip += columns.count;
                copy_index         += source_col - destination_col;
                continue;
            }

            values[it] = values[copy_index];
            copy_index += 1;
            it += 1;
        }
        assert((copy_index - it) == slots_to_delete);
    } else {
        // We insert one value for each row in the newly added column.
        // Columns are non-consecutive, so we need to move over all the
        //  pre-existing values and add some new ones at regular intervals.

        new_columns_count := columns.count + destination_col - source_col;
        first_index_to_update     := source_col;                                        // first row + source column index
        next_index_for_a_new_slot := new_columns_count * (rows.count - 1) + source_col; // last row  + source column index
        copy_index                := columns.count * rows.count - 1;                    // last slot, pre-resize

        for < first_index_to_update .. values.count-1 {
            if it == next_index_for_a_new_slot {
                values[it] = ifx source_col == 0 then Uninitialized_Value else values[copy_index];
                next_index_for_a_new_slot -= new_columns_count;
                continue;
            }

            values[it] = values[copy_index];
            copy_index -= 1;
        }
    }
}




TESTS :: false;

#if TESTS #run {
//#scope_export
//main :: () {
    #import "Basic";

    test_basic_add();
    test_basic_remove();
}

#if TESTS {
test_basic_add :: () {
    m: Spatial_Matrix(int, int, Uninitialized_Value = -1);

    Test_Value :: struct {
        x, y: int;
        v: int;

        new_row, new_col: bool;
    }
    test_values :: Test_Value.[
        .{ 0,  1, 15,   true,  true},
        .{12,  7, 16,   true,  true},
        .{ 1, 34, 17,   true,  true},
        .{24,  7, 18,  false,  true},
        .{17, 12, 19,   true,  true},
        .{53,  8, 20,   true,  true},
        .{ 1,  0, 21,   true, false},
    ];

    check_dimensions :: () #expand {
        assert(`m.rows.count    == `expected_rows, "[Test/Spatial_Matrix/basic_add] Expected row count to be %. Was %.\n", `expected_rows, `m.rows.count);
        assert(`m.columns.count == `expected_cols, "[Test/Spatial_Matrix/basic_add] Expected column count to be %. Was %.\n", `expected_cols, `m.columns.count);
    }

    expected_rows := 0;
    expected_cols := 0;

    check_dimensions();

    for test: test_values {
        using test;
        add_at(*m, y, x, v);

        if new_row expected_rows += 1;
        if new_col expected_cols += 1;

        check_dimensions();

        assert(get_at(m, y, x) == v, "[Test/Spatial_Matrix/basic_add] Expected stored value at (%, %) to be %. Was %.", y, x, v, get_at(m, y, x));
    }

    for test: test_values {
        using test;

        assert(get_at(m, y, x) == v, "[Test/Spatial_Matrix/basic_add] Expected stored value at (%, %) to be %. Was %.", y, x, v, get_at(m, y, x));
    }
}

test_basic_remove :: () {
    m: Spatial_Matrix(int, int, Uninitialized_Value = -1);

    test_count :: 128;

    check_dimensions :: (rows: int, cols: int) #expand {
        assert(`m.rows.count    == rows, "[Test/Spatial_Matrix/basic_remove] Expected row count to be %. Was %.\n", rows, `m.rows.count);
        assert(`m.columns.count == cols, "[Test/Spatial_Matrix/basic_remove] Expected column count to be %. Was %.\n", cols, `m.columns.count);
    }

    for 0..test_count-1 {
        add_at(*m, it, it, it * it);

        check_dimensions(it + 1, it + 1);
    }

    for 0..test_count-1 {
        remove_at(*m, it, it);

        expected_matrix_size := test_count - 1 - it;
        check_dimensions(expected_matrix_size, expected_matrix_size);
    }
}
}
