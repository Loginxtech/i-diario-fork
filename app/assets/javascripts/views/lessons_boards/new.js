$(function () {
  'use strict';
  const flashMessages = new FlashMessages();
  const period_div = $('#period');

  $(document).ready( function() {
    clearFields();
    clearClassroomsAndGrades();
  });

  $('#lessons_board_unity').on('change', async function () {
    clearFields();
    clearClassroomsAndGrades();
    period_div.hide();
    await updateGrades();
  })

  $('#lessons_board_grade').on('change', async function () {
    clearFields();
    period_div.hide();
    await updateClassrooms();
  })

  $('#lessons_board_classroom_id').on('change', async function () {
    $('#lessons_board_period').select2('val', '');
    await getPeriod();
    let period = $('#lessons_number_classroom_id').val();

    if (period != 4) {
      await checkNotExistsLessonsBoard();
    }

    period_div.show();
  })

  $('#lessons_board_period').on('change', function() {
    let period = $('#lessons_number_classroom_id').val();

    if (period == 4) {
      checkNotExistsLessonsBoardOnPeriod();
    }
  })

  async function updateGrades() {
    let unity_id = $('#lessons_board_unity').select2('val');
    if (!_.isEmpty(unity_id)) {
      $.ajax({
        url: Routes.grades_by_unity_lessons_boards_pt_br_path({
          unity_id: unity_id,
          format: 'json'
        }),
        success: handleFetchGradesSuccess,
        error: handleFetchGradesError
      });
    }
  }

  function handleFetchGradesSuccess(data) {
    let grades = _.map(data.lessons_boards, function(lessons_board) {
      return { id: lessons_board.table.id, name: lessons_board.table.name, text: lessons_board.table.text };
    });

    $('#lessons_board_grade').select2({ data: grades })
  }

  function handleFetchGradesError() {
    flashMessages.error('Ocorreu um erro ao buscar as séries');
  }

  async function updateClassrooms() {
    let unity_id = $('#lessons_board_unity').select2('val');
    let grade_id = $('#lessons_board_grade').select2('val');
    if (!_.isEmpty(grade_id) || !_.isEmpty(unity_id)) {
      $.ajax({
        url: Routes.classrooms_filter_lessons_boards_pt_br_path({
          unity_id: unity_id,
          grade_id: grade_id,
          format: 'json'
        }),
        success: handleFetchClassroomsSuccess,
        error: handleFetchClassroomsError
      });
    }
  }

  function handleFetchClassroomsSuccess(data) {
    let classrooms = _.map(data.lessons_boards, function(lessons_board) {
      return { id: lessons_board.table.id, name: lessons_board.table.name, text: lessons_board.table.text };
    });
    $('#lessons_board_classroom_id').select2({ data: classrooms })
  }

  function handleFetchClassroomsError() {
    flashMessages.error('Ocorreu um erro ao buscar as turmas');
  }

  async function getPeriod() {
    let classroom_id = $('#lessons_board_classroom_id').select2('val');

    if (!_.isEmpty(classroom_id)) {
      await $.ajax({
        url: Routes.period_lessons_boards_pt_br_path({
          classroom_id: classroom_id,
          format: 'json'
        }),
        success: handleFetchPeriodByClassroomSuccess,
        error: handleFetchPeriodByClassroomError
      });
    }
  }

  function handleFetchPeriodByClassroomSuccess(data) {
    $('#lessons_number_classroom_id').val(data);
    let period = $('#lessons_board_period');

    if (data != 4) {
      getNumberOfClasses();
      getTeachersFromClassroom();
      period.val(data).trigger("change")
      period.attr('readonly', true)
    } else {
      period.attr('readonly', false)
    }
  };

  function handleFetchPeriodByClassroomError() {
    flashMessages.error('Ocorreu um erro ao buscar o período da turma');
  };

  async function checkNotExistsLessonsBoard() {
    let classroom_id = $('#lessons_board_classroom_id').select2('val');

    if (!_.isEmpty(classroom_id)) {
      $.ajax({
        url: Routes.not_exists_by_classroom_lessons_boards_pt_br_path({
          classroom_id: classroom_id,
          format: 'json'
        }),
        success: handleNotExistsLessonsBoardSuccess,
        error: handleNotExistsLessonsBoardError
      });
    }
  }

  async function handleNotExistsLessonsBoardSuccess(data) {
    let period = $('#lessons_number_classroom_id').val();

    if (period == 4 && data) {
      flashMessages.pop('');
      $('#btn-submit').attr("disabled", false);
    } else {
      clearFields();
      $('#btn-submit').attr("disabled", true);
      flashMessages.error('já existe um quadro de aulas para a turma informada');
    }
  }

  function handleNotExistsLessonsBoardError() {
    flashMessages.error('Ocorreu um erro ao validar a existencia de uma calendário para essa turma');
  }

  function checkNotExistsLessonsBoardOnPeriod() {
    let classroom_id = $('#lessons_board_classroom_id').select2('val');
    let period = $('#lessons_board_period').select2('val');
    if (!_.isEmpty(classroom_id)) {
      $.ajax({
        url: Routes.not_exists_by_classroom_and_period_lessons_boards_pt_br_path({
          classroom_id: classroom_id,
          period: period,
          format: 'json'
        }),
        success: handleNotExistsLessonsBoardOnPeriodSuccess,
        error: handleNotExistsLessonsBoardOnPeriodError
      });
    }
  }

  async function handleNotExistsLessonsBoardOnPeriodSuccess(data) {
    if (data) {
      flashMessages.pop('');
      $('#btn-submit').attr("disabled", false);
      getNumberOfClasses();
      await getTeachersFromClassroomAndPeriod();
    } else {
      clearFields();
      $('#btn-submit').attr("disabled", true);
      flashMessages.error('Não é possível criar um novo quadro de aulas pois a turma especificada já possui um quadro de aulas criado com esse período');
    }
  }

  function handleNotExistsLessonsBoardOnPeriodError() {
    flashMessages.error('Ocorreu um erro ao validar a existencia de uma calendário para essa turma e período');
  }

  async function getTeachersFromClassroom() {
    let classroom_id = $('#lessons_board_classroom_id').select2('val');

    if (!_.isEmpty(classroom_id)) {
      return $.ajax({
        url: Routes.teachers_classroom_lessons_boards_pt_br_path({
          classroom_id: classroom_id,
          format: 'json'
        }),
        success: handleFetchTeachersFromTheClassroomSuccess,
        error: handleFetchTeachersFromTheClassroomError
      });
    }
  }

  async function getTeachersFromClassroomAndPeriod() {
    let classroom_id = $('#lessons_board_classroom_id').select2('val');
    let period = $('#lessons_board_period').select2('val');

    if (!_.isEmpty(classroom_id)) {
      return $.ajax({
               url: Routes.teachers_classroom_period_lessons_boards_pt_br_path({
                 classroom_id: classroom_id,
                 period: period,
                 format: 'json'
               }),
               success: handleFetchTeachersFromTheClassroomSuccess,
               error: handleFetchTeachersFromTheClassroomError
             });
    }
  }

  function handleFetchTeachersFromTheClassroomSuccess(data) {
    let teachers_to_select = _.map(data.lessons_boards, function(lessons_board) {
      return { id: lessons_board.table.id, name: lessons_board.table.name, text: lessons_board.table.text };
    });

    $("input[id*='_teacher_discipline_classroom_id']").each(function (index, teachers) {
      $(teachers).select2({ data: teachers_to_select })
    })
  }

  function handleFetchTeachersFromTheClassroomError() {
    flashMessages.error('Ocorreu um erro ao buscar os professores da turma');
  }

  function getNumberOfClasses() {
    let classroom_id = $('#lessons_board_classroom_id').select2('val');

    $.ajax({
      url: Routes.number_of_lessons_lessons_boards_pt_br_path({
        classroom_id: classroom_id,
        format: 'json'
      }),
      success: handleFetchNumberOfClassesByClassroomSuccess,
      error: handleFetchNumberOfClassesByClassroomError
    });
  }


  function handleFetchNumberOfClassesByClassroomSuccess(data) {
    flashMessages.pop('');

    if ($("#lessons-board-lessons > tr").length > 1) {
      $("#lessons-board-lessons").empty();
    }

    for (let i = 1; i <= data; i++) {
      $('#add_row').trigger('click')
    }

    $("input[id*='_lesson_number']").each(function (index, lesson_number) {
      $(lesson_number).val(index + 1)
    })
  }

  function handleFetchNumberOfClassesByClassroomError() {
    flashMessages.error('Ocorreu um erro ao buscar os numeros de aula da turma.');
  }

  function clearClassroomsAndGrades() {
    $('#lessons_board_classroom_id').select2('val', '');
    $('#lessons_board_grade').select2('val', '');
  }

  function clearFields() {
    $("#lessons-board-lessons").empty();
  }
});
