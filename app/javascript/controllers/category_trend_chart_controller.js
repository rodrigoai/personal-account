import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    series: Array,
    categories: Array,
    colors: Array
  }

  connect() {
    this.handleThemeChange = this.handleThemeChange.bind(this)
    window.addEventListener("ledgerly:theme-change", this.handleThemeChange)

    if (!window.ApexCharts) {
      this.element.innerHTML = '<p class="chart-load-error">The category chart could not be loaded.</p>'
      return
    }

    this.chart = new window.ApexCharts(this.element, this.options())
    this.chart.render()
  }

  disconnect() {
    window.removeEventListener("ledgerly:theme-change", this.handleThemeChange)
    this.chart?.destroy()
    this.chart = null
  }

  handleThemeChange() {
    this.chart?.updateOptions(this.themeOptions(), false, false)
  }

  options() {
    return {
      chart: {
        type: "line",
        height: 340,
        background: "transparent",
        fontFamily: "Manrope, sans-serif",
        animations: { enabled: !window.matchMedia("(prefers-reduced-motion: reduce)").matches },
        toolbar: { show: false },
        zoom: { enabled: false }
      },
      series: this.seriesValue,
      colors: this.colorsValue,
      theme: { mode: this.themeColors().mode },
      stroke: { curve: "smooth", width: 3, lineCap: "round" },
      markers: { size: 4, strokeWidth: 2, hover: { sizeOffset: 2 } },
      dataLabels: { enabled: false },
      grid: { borderColor: this.themeColors().grid, strokeDashArray: 3, padding: { left: 10, right: 10 } },
      legend: {
        position: "top",
        horizontalAlign: "left",
        fontWeight: 700,
        labels: { colors: this.themeColors().label },
        markers: { size: 6, shape: "circle" }
      },
      xaxis: {
        categories: this.categoriesValue,
        axisBorder: { show: false },
        axisTicks: { show: false },
        labels: { style: { colors: this.themeColors().label, fontFamily: "DM Mono, monospace", fontSize: "10px" } }
      },
      yaxis: {
        min: 0,
        forceNiceScale: true,
        labels: {
          formatter: value => this.formatCurrency(value, 0),
          style: { colors: this.themeColors().label, fontFamily: "DM Mono, monospace", fontSize: "10px" }
        }
      },
      tooltip: { y: { formatter: value => this.formatCurrency(value, 2) } },
      noData: { text: "No totals in this period" }
    }
  }

  themeOptions() {
    const colors = this.themeColors()
    return {
      theme: { mode: colors.mode },
      grid: { borderColor: colors.grid },
      legend: { labels: { colors: colors.label } },
      xaxis: { labels: { style: { colors: colors.label } } },
      yaxis: { labels: { style: { colors: colors.label } } }
    }
  }

  themeColors() {
    const dark = document.documentElement.dataset.theme === "dark"
    return dark
      ? { mode: "dark", grid: "#31403C", label: "#91A199" }
      : { mode: "light", grid: "#E1E4DC", label: "#87928B" }
  }

  formatCurrency(value, precision) {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL",
      minimumFractionDigits: precision,
      maximumFractionDigits: precision
    }).format(value)
  }
}
