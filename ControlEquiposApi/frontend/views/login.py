import flet as ft
import requests

def LoginView(page: ft.Page, on_login_success):
    email_input = ft.TextField(label="Correo Electrónico", width=300, autofocus=True)
    password_input = ft.TextField(label="Contraseña", password=True, can_reveal_password=True, width=300)
    error_text = ft.Text(value="", color=ft.Colors.RED_400)
    login_btn = ft.ElevatedButton("Iniciar Sesión", width=300, bgcolor=ft.Colors.BLUE_500, color=ft.Colors.WHITE)

    def btn_click(e):
        error_text.value = ""
        login_btn.disabled = True
        page.update()

        try:
            # Petición a la API
            response = requests.post(
                "http://127.0.0.1:7000/api/api/auth/login",
                json={"email": email_input.value, "password": password_input.value}
            )

            if response.status_code == 200:
                data = response.json()
                token = data.get("access_token")
                
                # Gestión de almacenamiento (prioridad client_storage)
                try:
                    page.client_storage.set("token", token)
                except Exception:
                    page.session.set("token", token)
                
                on_login_success()
            else:
                error_text.value = "Credenciales incorrectas."
        
        except requests.exceptions.ConnectionError:
            error_text.value = "No se pudo conectar con el servidor."
        except Exception as ex:
            error_text.value = "Ocurrió un error inesperado."
            print(f"Error técnico: {ex}")
        
        login_btn.disabled = False
        page.update()

    login_btn.on_click = btn_click

    return ft.Card(
        content=ft.Container(
            content=ft.Column([
                ft.Text("Soluciones Peralme", size=28, weight=ft.FontWeight.BOLD, color=ft.Colors.BLUE_500),
                ft.Text("Control de Equipos TIC", size=16, color=ft.Colors.GREY_600),
                ft.Divider(),
                email_input,
                password_input,
                error_text,
                login_btn
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=15),
            padding=40,
        )
    )