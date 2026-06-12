import flet as ft
from views.login import LoginView
from views.dashboard import DashboardView

def main(page: ft.Page):
    page.title = "Sistema de Control de Equipos - Soluciones Peralme"
    page.theme_mode = ft.ThemeMode.LIGHT
    
    # Propiedades modernas para la ventana en Flet 0.24+
    page.window.width = 1100
    page.window.height = 700
    page.window.resizable = True

    def ir_al_dashboard():
        page.controls.clear()
        page.vertical_alignment = ft.MainAxisAlignment.START
        page.horizontal_alignment = ft.CrossAxisAlignment.START
        
        dashboard_layout = DashboardView(page, on_logout=mostrar_login)
        page.add(dashboard_layout)
        page.update()

    def mostrar_login():
        page.controls.clear()
        page.vertical_alignment = ft.MainAxisAlignment.CENTER
        page.horizontal_alignment = ft.CrossAxisAlignment.CENTER
        
        login_card = LoginView(page, on_login_success=ir_al_dashboard)
        page.add(login_card)
        page.update()

    # Arranca forzando el Login
    mostrar_login()

if __name__ == "__main__":
    # ft.run es la forma correcta de iniciar la app web
    ft.run(main, port=8085, view=ft.AppView.WEB_BROWSER)