require([
  'underscore',
  'jquery',
  'splunkjs/mvc',
  'splunkjs/mvc/tableview',
  'splunkjs/mvc/simplexml/ready!'
], function(_, $, mvc, TableView) {
  console.log('img_renderer getting defined');
  var CustomIconRenderer = TableView.BaseCellRenderer.extend({
    canRender: function(cell) {
      console.log('canRender called...' + cell.field);
      return cell.field === 'url';
    },
    render: function($td, cell) {
      console.log('render called...' + cell.value);
      // Create the icon element and add it to the table cell
      $td.addClass('artist-image').html(_.template('<img src="http://userserve-ak.last.fm/serve/126/75527962.jpg">', {
        url: cell.value.trim()
      }));
    }
  });
  mvc.Components.get('table1').getVisualization(function(tableView){
    // Register custom cell renderer
    tableView.table.addCellRenderer(new CustomIconRenderer());
    // Force the table to re-render
    tableView.table.render();
  });
});