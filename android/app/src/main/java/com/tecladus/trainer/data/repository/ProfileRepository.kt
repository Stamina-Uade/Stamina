package com.tecladus.trainer.data.repository

import com.tecladus.trainer.data.local.ProfileStore
import com.tecladus.trainer.domain.model.UserProfile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

/**
 * Contrato del perfil. Hoy resuelve contra almacenamiento local; el día que exista
 * backend basta con crear otra implementación (RemoteProfileRepository) sin tocar la UI.
 */
interface ProfileRepository {
    val profile: StateFlow<UserProfile>
    suspend fun save(profile: UserProfile)
}

class LocalProfileRepository(private val store: ProfileStore) : ProfileRepository {

    private val _profile = MutableStateFlow(store.load())
    override val profile: StateFlow<UserProfile> = _profile.asStateFlow()

    override suspend fun save(profile: UserProfile) {
        withContext(Dispatchers.IO) { store.save(profile) }
        _profile.value = profile
    }
}
