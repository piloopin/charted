/*
 * Copyright 2014 Google Inc. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file or at
 * https://developers.google.com/open-source/licenses/bsd
 */

library charted.demo.interactive;

import 'dart:html';
import 'package:observe/observe.dart';
import 'package:charted/charts/charts.dart';

import 'charts_demo.dart';

const List DIMENSION_COLUMNS =  const[0, 4];

int customSeriesCounter = 0;

Map RENDERERS = {
  'bar-chart': 'Bar chart',
  'line-chart': 'Line chart',
  'stacked-bar-chart': 'Stacked bar chart',
  'waterfall-chart': 'Waterfall chart',
};

ChartRenderer getRendererForType(String name) {
  if (name == 'bar-chart') return new BarChartRenderer();
  if (name == 'line-chart') return new LineChartRenderer();
  if (name == 'stacked-bar-chart') return new StackedBarChartRenderer();
  return new BarChartRenderer();
}

String getTypeForRenderer(ChartRenderer renderer) {
  if (renderer is BarChartRenderer) return 'bar-chart';
  if (renderer is LineChartRenderer) return 'line-chart';
  if (renderer is StackedBarChartRenderer) return 'stacked-bar-chart';
  return 'bar-chart';
}

main() {
  List DATA_SOURCE = SMALL_DATA;
  ChartSeries activeSeries,
      defaultSeries = new ChartSeries("Default series",
          new ObservableList.from([ 2, 3 ]), new BarChartRenderer());

  ObservableList rows = new ObservableList.from(DATA_SOURCE.sublist(0, 10)),
      columns = new ObservableList.from(SMALL_DATA_COLUMNS),
      seriesList = new ObservableList.from([ defaultSeries ]);

  ChartData data = new ChartData(columns, rows);
  ChartConfig config = new ChartConfig(seriesList, DIMENSION_COLUMNS);

  ChartArea area = new ChartArea(querySelector('.chart-host'), data, config,
      autoUpdate: true, useTwoDimensionAxes: false);

  area.addChartBehavior(new ChartTooltip());
  config.legend = new ChartLegend(querySelector('.chart-legend-host'));

  area.draw();

  /*
   * Create and hook up the control panel
   */

  ButtonElement addRowButton = querySelector('#add-row'),
      removeRowButton = querySelector('#remove-row'),
      addSeriesButton = querySelector('#add-series'),
      removeSeriesButton = querySelector('#remove-series');

  InputElement useRTLScriptCheckBox = querySelector('#rtl-use-script'),
      switchAxesForRTLCheckBox = querySelector('#rtl-switch-axes'),
      useRTLLayoutCheckBox = querySelector('#rtl-use-layout');

  SelectElement seriesSelect = querySelector('#select-series'),
      rendererSelect = querySelector('#select-renderer');

  Element columnButtons = querySelector('#column-buttons'),
      chartsContainer = querySelector('.chart-wrapper');

  /*
   * RTL handling
   */

  useRTLLayoutCheckBox.onChange.listen((_) {
    bool isRTL = useRTLLayoutCheckBox.checked;
    config.isRTL = isRTL;
    chartsContainer.attributes['dir'] = isRTL ? 'rtl' : 'ltr';
  });

  useRTLScriptCheckBox.onChange.listen((_) {
    bool isRTL = useRTLScriptCheckBox.checked;
    rows.clear();
    DATA_SOURCE = isRTL ? SMALL_DATA_RTL : SMALL_DATA;
    rows.addAll(DATA_SOURCE.sublist(0, 10));
  });

  /*
   * Updating rows
   */

  updateRowButtonStates() {
    addRowButton.disabled = rows.length >= DATA_SOURCE.length;
    removeRowButton.disabled = rows.length <= 1;
  }

  addRowButton.onClick.listen((_) {
    if (rows.length < DATA_SOURCE.length) {
      rows.add(DATA_SOURCE.elementAt(rows.length));
    }
    updateRowButtonStates();
  });

  removeRowButton.onClick.listen((_) {
    if (rows.length > 0) rows.removeLast();
    updateRowButtonStates();
  });


  /*
   * Series selection
   */

  selectSeries(ChartSeries series) {
    activeSeries = series;

    List<Element> options = rendererSelect.children.toList();
    String rendererType = getTypeForRenderer(series.renderer);
    for (int i = 0; i < options.length; i++) {
      if ((options[i] as OptionElement).value == rendererType)
        rendererSelect.selectedIndex = i;
    }

    List buttons = querySelectorAll('.column-button');
    Iterable measures = series.measures;
    for (int i = 0; i < buttons.length; i++) {
      buttons[i].checked = measures.contains(i + 1);
    }
  }

  updateSeriesSelector([ChartSeries selected]) {
    seriesSelect.children.clear();
    seriesList.forEach((ChartSeries item) {
      var option = new OptionElement()
          ..value = item.name
          ..text = item.name;
      seriesSelect.append(option);
    });
    selectSeries(selected == null ? seriesList.first : selected);
  }

  seriesSelect.onChange.listen(
      (_) => selectSeries(seriesList.firstWhere(
          (ChartSeries x) => x.name == seriesSelect.value)));


  /*
   * Renderer selection for active series
   */

  updateRendererSelector() {
    rendererSelect.children.clear();
    RENDERERS.forEach((name, label) {
      var option = new OptionElement()
          ..value = name
          ..text = label;
      rendererSelect.append(option);
    });
  }

  rendererSelect.onChange.listen((_) {
      activeSeries.renderer = getRendererForType(rendererSelect.value);
    });


  /*
   * Column selection on active series
   */

  updateColumns([Event e]) {
    if (activeSeries == null) return;

    List<Element> buttons = querySelectorAll('.column-button');
    InputElement firstChecked;
    for (int i = 0; i < buttons.length && firstChecked == null; i++) {
      if ((buttons[i] as InputElement).checked) firstChecked = buttons[i];
    }

    List measures = activeSeries.measures as List;
    int index = buttons.indexOf(e.target) + 1;
    if ((e.target as InputElement).checked) {
      measures.add(index);
      buttons.forEach((InputElement b) => b.disabled = false);
    } else {
      measures.remove(index);
      if (measures.length <= 1) firstChecked.disabled = true;
    }
  }

  updateColumnsList() {
    columnButtons.children.clear();
    SMALL_DATA_COLUMNS.asMap().forEach((int index, ChartColumnSpec spec) {
      if (index == 0) return;
      var row = new DivElement();
      var button = new InputElement()
          ..className = 'column-button'
          ..type = 'checkbox'
          ..value = spec.label
          ..id = 'column-$index'
          ..onChange.listen((e) => updateColumns(e));
      var label = new LabelElement()
          ..text = spec.label
          ..htmlFor = 'column-$index';
      row.children.addAll([button,label]);
      columnButtons.append(row);
    });
  }


  /*
   * Updates to series
   */

  updateSeriesButtonStates() {
    removeSeriesButton.disabled = seriesList.length <= 1;
  }

  addSeriesButton.onClick.listen((_) {
    var name = 'New Series ${customSeriesCounter}',
        series = new ChartSeries(name, new ObservableList.from([1, 2, 3]),
            new BarChartRenderer());
    seriesList.add(series);
    updateSeriesSelector(series);
    seriesSelect.selectedIndex = seriesList.length - 1;
    updateSeriesButtonStates();
    customSeriesCounter++;
  });

  removeSeriesButton.onClick.listen((_) {
    if (seriesList.length > 0) seriesList.removeLast();
    updateSeriesSelector();
    updateSeriesButtonStates();
  });


  /*
   * Update UI
   */

  updateColumnsList();
  updateRendererSelector();
  updateSeriesSelector();
}
