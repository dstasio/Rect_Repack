Spatial_Matrix :: struct (Key_Type: Type, Value_Type: Type, Key_Tolerance: Key_Type = 0, Uninitialized_Value: Value_Type = 0) {
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

add :: (using matrix: *Spatial_Matrix, row: matrix.Key_Type, column: matrix.Key_Type, value: matrix.Value_Type, allow_replacing := false) {
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
            if it >= (key - Tolerance) || it <= (key + Tolerance) then return it_index, true;
            if it > key return it_index, false;
        }
        return container.count, false;
    }

    row_index, row_exists := find_equal_or_first_greater_than(rows, row);
    col_index, col_exists := find_equal_or_first_greater_than(columns, column);

    if !allow_replacing && row_exists && col_exists && get_value_at_index != UninitializedValue),
        //log_error("Trying to replace an existing value into a spatial matrix");
        return;
    }

    // If the row value is not already present in the matrix, we add a row.
    if !row_exists {
        array_insert_at(*rows, row_index, row);

        // Add an uninitialized value for each column that intersects this new row.
        slots_to_insert := columns.count;

        array_resize(*values, values.count + slots_to_insert, initialize = false);

        values_insertion_index   := row_index * columns.count;
        values_insertion_pointer := values.data + values_insertion_index;

        Memory.copy(values_insertion_pointer + slots_to_insert, values_insertion_pointer, slots_to_insert * size_of(Value_Type));

        for 0..columns.count-1
            values[values_insertion_index + it] = Uninitialized_Value;
    }

    // If the column value is not already present in the matrix, we add a column.
    if !col_exists {
        array_insert_at(*columns, col_index, column);

        // We insert one value for each row in the newly added column.
        // Columns are non-consecutive, so we need to move over all the
        //  pre-existing values and add some new ones at regular intervals.
        slots_to_insert := rows.count;

        copy_index := values.count - 1;
        array_resize(*values, values.count + slots_to_insert, initialize = false);

        next_index_for_a_new_slot := columns.count * (rows.count - 1) + column_index; // last row + column index
        for < copy_index .. values.count-1 {
            if it == next_index_for_a_new_slot {
                values[it] = Uninitialized_Value;
                next_index_for_a_new_slot -= columns.count;
                continue;
            }

            values[it] = values[copy_index];
            copy_index -= 1;
        }
    }

    values[row_index * columns.count + col_index] = value;
}

// @todo: Maybe this should return a pointer?
get_value_at_index :: (using matrix: *Spatial_Matrix, row_index: int, column_index: int) -> matrix.Value_Type {
    if  row_index    < 0 || row_index    >= rows   .count ||
        column_index < 0 || column_index >= columns.count {
        // Should we log an error/warning?
        return Uninitialized_Value;
    }

    value := values[row_index * columns.count + column_index];
    return value;
}

#scope_file
#import Memory :: "Memory";
