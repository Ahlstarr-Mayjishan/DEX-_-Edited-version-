using System;
using System.Windows.Forms;

namespace DEXHelperApp;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        Application.ThreadException += (_, e) => LogError(e.Exception);
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
        {
            if (e.ExceptionObject is Exception exception) LogError(exception);
        };

        try
        {
            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            ApplicationConfiguration.Initialize();
            Application.Run(new MainForm());
        }
        catch (Exception exception)
        {
            LogError(exception);
            MessageBox.Show(exception.Message, "DEX++ Helper App", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static void LogError(Exception exception)
    {
        try
        {
            File.AppendAllText(
                Path.Combine(AppContext.BaseDirectory, "app_error.log"),
                DateTime.Now.ToString("u") + Environment.NewLine + exception + Environment.NewLine + Environment.NewLine);
        }
        catch
        {
        }
    }
}
