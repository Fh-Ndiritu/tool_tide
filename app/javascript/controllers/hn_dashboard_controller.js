import { Controller } from "@hotwired/stimulus"
// import Chart from "chart.js/auto" -> usage via CDN/window.Chart

export default class extends Controller {
  static targets = ["canvas", "stats"]
  static values = {
    averagesDay: Object,
    averagesTime: Object,
    today: Object
  }

  connect() {
    this.waitForChart()
  }

  waitForChart(attempts = 0) {
    if (typeof Chart !== "undefined") {
      this.initChart()
      return
    }

    if (attempts > 20) {
      console.error("Chart.js failed to load after 2 seconds")
      return
    }

    setTimeout(() => this.waitForChart(attempts + 1), 100)
  }

  initChart() {
    const ctx = this.canvasTarget.getContext("2d")

    // Prepare Data
    // Backend sends data keys as UTC integer HHMM (e.g. 1430).
    // Combine keys from all datasets to ensure we show a full X-axis
    const allKeys = new Set([
      ...Object.keys(this.averagesDayValue),
      ...Object.keys(this.averagesTimeValue),
      ...Object.keys(this.todayValue)
    ])
    const utcBuckets = Array.from(allKeys).map(Number)

    // Helper to Convert UTC HHMM -> Local HH:MM string and sortable value
    const bucketData = utcBuckets.map(utc => {
      const h = Math.floor(utc / 100)
      const m = utc % 100

      const date = new Date()
      date.setUTCHours(h, m, 0, 0)

      // Local time buckets for sorting (hours * 60 + mins)
      const localMinutes = date.getHours() * 60 + date.getMinutes()

      // Label
      const label = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })

      return { utc, localMinutes, label }
    })

    // Sort by local time
    bucketData.sort((a, b) => a.localMinutes - b.localMinutes)

    const labels = bucketData.map(b => b.label)

    // Map data using the *sorted* original UTC keys
    const avgDayData = bucketData.map(b => this.averagesDayValue[b.utc] || 0)
    const avgTimeData = bucketData.map(b => this.averagesTimeValue[b.utc] || 0)

    // Today: might be partial.
    const todayData = bucketData.map(b => this.todayValue[b.utc] || null)
    // using null to break line if we haven't reached that time yet?
    // Or 0? If it's "future", better be null.
    // Assuming backend provided todayValue for *past* buckets only.

    // Create Gradients
    const gradientToday = ctx.createLinearGradient(0, 0, 0, 400);
    gradientToday.addColorStop(0, 'rgba(249, 115, 22, 0.4)');   // Orange-500
    gradientToday.addColorStop(1, 'rgba(249, 115, 22, 0.0)');

    const gradientAvg = ctx.createLinearGradient(0, 0, 0, 400);
    gradientAvg.addColorStop(0, 'rgba(59, 130, 246, 0.2)');    // Blue-500
    gradientAvg.addColorStop(1, 'rgba(59, 130, 246, 0.0)');

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Avg (This Day)',
            data: avgDayData,
            borderColor: '#3b82f6', // blue-500
            backgroundColor: gradientAvg,
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 4,
            fill: false,
            tension: 0.4
          },
          {
            label: 'Avg (All Time)',
            data: avgTimeData,
            borderColor: '#8b5cf6', // violet-500
            backgroundColor: 'transparent',
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 4,
            borderDash: [5, 5],
            fill: false,
            tension: 0.4
          },
          {
            label: "Today's Activity",
            data: todayData,
            borderColor: '#f97316', // orange-500
            backgroundColor: gradientToday,
            borderWidth: 3,
            pointBackgroundColor: '#fff',
            pointBorderColor: '#f97316',
            pointRadius: 4,
            pointHoverRadius: 6,
            fill: true,
            tension: 0.4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
            align: 'end',
            labels: {
              usePointStyle: true,
              boxWidth: 8,
              font: { family: "'Inter', sans-serif", size: 12 }
            }
          },
          tooltip: {
            mode: 'index',
            intersect: false,
            padding: 10,
            cornerRadius: 8,
            backgroundColor: 'rgba(255, 255, 255, 0.9)',
            titleColor: '#1f2937',
            bodyColor: '#4b5563',
            borderColor: '#e5e7eb',
            borderWidth: 1,
            titleFont: { family: "'Inter', sans-serif", size: 14, weight: 'bold' },
            bodyFont: { family: "'Inter', sans-serif", size: 13 }
          },
          title: { display: false }
        },
        scales: {
            x: {
                grid: { display: false },
                ticks: {
                    font: { family: "'Inter', sans-serif", size: 11 },
                    color: '#9ca3af',
                    maxTicksLimit: 12
                }
            },
          y: {
            beginAtZero: true,
            grid: {
                color: '#f3f4f6',
                borderDash: [2, 2]
            },
             ticks: {
                    font: { family: "'Inter', sans-serif", size: 11 },
                    color: '#9ca3af'
                },
             border: { display: false }
          }
        },
        interaction: {
          mode: 'nearest',
          axis: 'x',
          intersect: false
        }
      }
    })
  }

  // Called when Turbo Stream replaces the stats element
  updateStats(event) {
    // The "stats" target was replaced. It has new data attributes.
    // Read them and add to chart.
    const element = this.statsTarget
    const count = parseInt(element.dataset.latestCount)
    const timeBucket = parseInt(element.dataset.latestBucket)

    if (!isNaN(count) && !isNaN(timeBucket)) {
       this.addDataPoint(timeBucket, count)
    }
  }

  addDataPoint(timeBucket, count) {
    if (!this.chart) return

    // Re-generate the sorted order to find the correct index for this UTC bucket
    // Must use same union logic as initChart to match the X-axis
    const allKeys = new Set([
      ...Object.keys(this.averagesDayValue),
      ...Object.keys(this.averagesTimeValue),
      ...Object.keys(this.todayValue)
    ])
    // Ensure the new point's bucket is included if it wasn't already (unlikely for fixed buckets but safe)
    allKeys.add(String(timeBucket))

    const utcBuckets = Array.from(allKeys).map(Number)
    const bucketData = utcBuckets.map(utc => {
      const h = Math.floor(utc / 100)
      const m = utc % 100
      const date = new Date()
      date.setUTCHours(h, m, 0, 0)
      const localMinutes = date.getHours() * 60 + date.getMinutes()
      return { utc, localMinutes }
    })
    bucketData.sort((a, b) => a.localMinutes - b.localMinutes)

    // Find index of the incoming UTC bucket
    const index = bucketData.findIndex(b => b.utc === timeBucket)

    if (index !== -1) {
      // Update Today's dataset (index 2)
      this.chart.data.datasets[2].data[index] = count
      this.chart.update()
    }
  }

  // Triggered by mutation observer or simplify:
  // We can use a Stimulus "targetConnected" callback.
  statsTargetConnected(element) {
    // If we have a chart, try to update it
    if (this.chart) {
      const count = element.dataset.latestCount
      const bucket = element.dataset.latestBucket
      if (count && bucket) {
        this.addDataPoint(parseInt(bucket), parseInt(count))
      }
    }
  }
}
